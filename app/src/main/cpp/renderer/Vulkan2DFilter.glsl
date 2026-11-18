// Independent 2D reconstruction. Original 3D and mixed/captured pixels
// bypass this code. Provenance is authored by the faithful compositor, never
// guessed from colours or game IDs. No new GPU attachments or readbacks.
#define TextureSize vec2(256.0, 192.0)
#define mul(a,b) (b*a)

vec4 filter2DSource(vec2 local, bool topScreen)
{
    vec2 uv = uvFromScreenLocal(local, topScreen);
    ivec2 size = textureSize(uTexture, 0);
    ivec2 p = clamp(ivec2(uv * vec2(size)), ivec2(0), size - 1);
    return texelFetch(uTexture, p, 0);
}

bool filter2DCertified(vec4 source)
{
    return abs(source.a - 128.0 / 255.0) < 0.5 / 255.0;
}

vec3 sample2DNative(vec2 local, bool topScreen)
{
    vec2 center = (floor(clamp(local, vec2(0.0), vec2(0.999999)) * TextureSize) + 0.5) / TextureSize;
    return filter2DSource(center, topScreen).bgr;
}

#define CORNER_C
#define SMOOTH_TIPS
#define XBR_SCALE 4.0
#define XBR_Y_WEIGHT 48.0
#define XBR_EQ_THRESHOLD 15.0
#define XBR_LV1_COEFFICIENT 0.5
#define XBR_LV2_COEFFICIENT 2.0
#define lv2_cf XBR_LV2_COEFFICIENT
#define small_details 1.0
/*
   Hyllian's xBR-lv2 Shader

   Copyright (C) 2011-2016 Hyllian - sergiogdb@gmail.com

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

   Incorporates some of the ideas from SABR shader. Thanks to Joshua Street.
*/
const float coef         = 2.0;
const vec3 rgbw          = vec3(14.352, 28.176, 5.472);
const vec4 eq_threshold  = vec4(15.0, 15.0, 15.0, 15.0);

const vec4 delta   = vec4(1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE, 1.0/XBR_SCALE);
const vec4 delta_l = vec4(0.5/XBR_SCALE, 1.0/XBR_SCALE, 0.5/XBR_SCALE, 1.0/XBR_SCALE);
const vec4 delta_u = delta_l.yxwz;

const  vec4 Ao = vec4( 1.0, -1.0, -1.0, 1.0 );
const  vec4 Bo = vec4( 1.0,  1.0, -1.0,-1.0 );
const  vec4 Co = vec4( 1.5,  0.5, -0.5, 0.5 );
const  vec4 Ax = vec4( 1.0, -1.0, -1.0, 1.0 );
const  vec4 Bx = vec4( 0.5,  2.0, -0.5,-2.0 );
const  vec4 Cx = vec4( 1.0,  1.0, -0.5, 0.0 );
const  vec4 Ay = vec4( 1.0, -1.0, -1.0, 1.0 );
const  vec4 By = vec4( 2.0,  0.5, -2.0,-0.5 );
const  vec4 Cy = vec4( 2.0,  0.0, -1.0, 0.5 );
const  vec4 Ci = vec4(0.25, 0.25, 0.25, 0.25);

const vec3 Y = vec3(0.2126, 0.7152, 0.0722);

// Difference between vector components.
vec4 xbr2D_df(vec4 A, vec4 B)
{
    return vec4(abs(A-B));
}

// Compare two vectors and return their components are different.
vec4 xbr2D_diff(vec4 A, vec4 B)
{
    return vec4(notEqual(A, B));
}

// Determine if two vector components are equal based on a threshold.
vec4 xbr2D_eq(vec4 A, vec4 B)
{
    return (step(xbr2D_df(A, B), vec4(XBR_EQ_THRESHOLD)));
}

// Determine if two vector components are NOT equal based on a threshold.
vec4 xbr2D_neq(vec4 A, vec4 B)
{
    return (vec4(1.0, 1.0, 1.0, 1.0) - xbr2D_eq(A, B));
}

// Weighted distance.
vec4 xbr2D_wd(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h)
{
    return (xbr2D_df(a,b) + xbr2D_df(a,c) + xbr2D_df(d,e) + xbr2D_df(d,f) + 4.0*xbr2D_df(g,h));
}

vec4 xbr2D_weighted_distance(vec4 a, vec4 b, vec4 c, vec4 d, vec4 e, vec4 f, vec4 g, vec4 h, vec4 i, vec4 j, vec4 k, vec4 l)
{
	return (xbr2D_df(a,b) + xbr2D_df(a,c) + xbr2D_df(d,e) + xbr2D_df(d,f) + xbr2D_df(i,j) + xbr2D_df(k,l) + 2.0*xbr2D_df(g,h));
}

float xbr2D_c_df(vec3 c1, vec3 c2)
{
      vec3 xbr2D_df = abs(c1 - c2);
      return xbr2D_df.r + xbr2D_df.g + xbr2D_df.b;
}

// One analysis per distinct native cell. Pixel-aware resampling normally
// shades four subpixels of the SAME cell: reuse its 21 texture samples and
// edge decisions instead of evaluating the complete xBR kernel four times.
struct Xbr2DCell {
    vec3 E,B,D,F,H;
    vec4 px,edri,edr,edr_l,edr_u;
    bool valid;
};

vec3 sample2DForAnalysis(vec2 local, bool topScreen, inout bool certified)
{
    vec2 center=(floor(clamp(local,vec2(0.0),vec2(0.999999))*TextureSize)+0.5)/TextureSize;
    vec4 pixel=filter2DSource(center,topScreen);
    certified=certified && filter2DCertified(pixel);
    return pixel.bgr;
}

Xbr2DCell analyze2DCell(vec2 local, bool topScreen)
{
    Xbr2DCell result;
    vec2 texCoord=(floor(clamp(local,vec2(0.0),vec2(0.999999))*TextureSize)+0.5)/TextureSize;
 float dx=1.0/TextureSize.x, dy=1.0/TextureSize.y;
vec4 t1=texCoord.xxxy+vec4(-dx,0,dx,-2.0*dy);
vec4 t2=texCoord.xxxy+vec4(-dx,0,dx,-dy);
vec4 t3=texCoord.xxxy+vec4(-dx,0,dx,0);
vec4 t4=texCoord.xxxy+vec4(-dx,0,dx,dy);
vec4 t5=texCoord.xxxy+vec4(-dx,0,dx,2.0*dy);
vec4 t6=texCoord.xyyy+vec4(-2.0*dx,-dy,0,dy);
vec4 t7=texCoord.xyyy+vec4(2.0*dx,-dy,0,dy);

    vec4 edri, edr, edr_l, edr_u, px; // px = pixel, edr = edge detection rule
    vec4 irlv0, irlv1, irlv2l, irlv2u, block_3d;


    bool certified = true;

    vec3 A1 = sample2DForAnalysis(t1.xw, topScreen, certified);
    vec3 B1 = sample2DForAnalysis(t1.yw, topScreen, certified);
    vec3 C1 = sample2DForAnalysis(t1.zw, topScreen, certified);
    vec3 A  = sample2DForAnalysis(t2.xw, topScreen, certified);
    vec3 B  = sample2DForAnalysis(t2.yw, topScreen, certified);
    vec3 C  = sample2DForAnalysis(t2.zw, topScreen, certified);
    vec3 D  = sample2DForAnalysis(t3.xw, topScreen, certified);
    vec3 E  = sample2DForAnalysis(t3.yw, topScreen, certified);
    vec3 F  = sample2DForAnalysis(t3.zw, topScreen, certified);
    vec3 G  = sample2DForAnalysis(t4.xw, topScreen, certified);
    vec3 H  = sample2DForAnalysis(t4.yw, topScreen, certified);
    vec3 I  = sample2DForAnalysis(t4.zw, topScreen, certified);
    vec3 G5 = sample2DForAnalysis(t5.xw, topScreen, certified);
    vec3 H5 = sample2DForAnalysis(t5.yw, topScreen, certified);
    vec3 I5 = sample2DForAnalysis(t5.zw, topScreen, certified);
    vec3 A0 = sample2DForAnalysis(t6.xy, topScreen, certified);
    vec3 D0 = sample2DForAnalysis(t6.xz, topScreen, certified);
    vec3 G0 = sample2DForAnalysis(t6.xw, topScreen, certified);
    vec3 C4 = sample2DForAnalysis(t7.xy, topScreen, certified);
    vec3 F4 = sample2DForAnalysis(t7.xz, topScreen, certified);
    vec3 I4 = sample2DForAnalysis(t7.xw, topScreen, certified);

    vec4 b  = vec4(dot(B ,rgbw), dot(D ,rgbw), dot(H ,rgbw), dot(F ,rgbw));
    vec4 c  = vec4(dot(C ,rgbw), dot(A ,rgbw), dot(G ,rgbw), dot(I ,rgbw));
    vec4 d  = b.yzwx;
    vec4 e  = vec4(dot(E,rgbw));
    vec4 f  = b.wxyz;
    vec4 g  = c.zwxy;
    vec4 h  = b.zwxy;
    vec4 i  = c.wxyz;

	vec4 i4, i5, h5, f4;

	float y_weight = XBR_Y_WEIGHT;

	if (small_details < 0.5)
	{
		i4 = vec4(dot(I4,rgbw), dot(C1,rgbw), dot(A0,rgbw), dot(G5,rgbw));
		i5 = vec4(dot(I5,rgbw), dot(C4,rgbw), dot(A1,rgbw), dot(G0,rgbw));
		h5 = vec4(dot(H5,rgbw), dot(F4,rgbw), dot(B1,rgbw), dot(D0,rgbw));
	}
	else
	{
		i4 = mul( mat4x3(I4, C1, A0, G5), y_weight * Y );
		i5 = mul( mat4x3(I5, C4, A1, G0), y_weight * Y );
		h5 = mul( mat4x3(H5, F4, B1, D0), y_weight * Y );
	}
    f4 = h5.yzwx;

    if (!certified) { result.valid = false; return result; }
    irlv1 = irlv0 = xbr2D_diff(e,f) * xbr2D_diff(e,h);

#ifdef CORNER_B
    irlv1      = (irlv0 * ( xbr2D_neq(f,b) * xbr2D_neq(h,d) + xbr2D_eq(e,i) * xbr2D_neq(f,i4) * xbr2D_neq(h,i5) + xbr2D_eq(e,g) + xbr2D_eq(e,c) ) );
#endif
#ifdef CORNER_D
    vec4 c1 = i4.yzwx;
    vec4 g0 = i5.wxyz;
    irlv1     = (irlv0  *  ( xbr2D_neq(f,b) * xbr2D_neq(h,d) + xbr2D_eq(e,i) * xbr2D_neq(f,i4) * xbr2D_neq(h,i5) + xbr2D_eq(e,g) + xbr2D_eq(e,c) ) * (xbr2D_diff(f,f4) * xbr2D_diff(f,i) + xbr2D_diff(h,h5) * xbr2D_diff(h,i) + xbr2D_diff(h,g) + xbr2D_diff(f,c) + xbr2D_eq(b,c1) * xbr2D_eq(d,g0)));
#endif
#ifdef CORNER_C
    irlv1     = (irlv0  * ( xbr2D_neq(f,b) * xbr2D_neq(f,c) + xbr2D_neq(h,d) * xbr2D_neq(h,g) + xbr2D_eq(e,i) * (xbr2D_neq(f,f4) * xbr2D_neq(f,i4) + xbr2D_neq(h,h5) * xbr2D_neq(h,i5)) + xbr2D_eq(e,g) + xbr2D_eq(e,c)) );
#endif

    irlv2l = xbr2D_diff(e,g) * xbr2D_diff(d,g);
    irlv2u = xbr2D_diff(e,c) * xbr2D_diff(b,c);

    vec4 wd1, wd2;
	if (small_details < 0.5)
	{
		wd1 = xbr2D_wd( e, c,  g, i, h5, f4, h, f);
		wd2 = xbr2D_wd( h, d, i5, f, i4,  b, e, i);
	}
	else
	{
		wd1 = xbr2D_weighted_distance( e, c, g, i, f4, h5, h, f, b, d, i4, i5);
		wd2 = xbr2D_weighted_distance( h, d, i5, f, b, i4, e, i, g, h5, c, f4);
	}

    edri  = step(wd1, wd2) * irlv0;
    edr   = step(wd1 + vec4(0.1, 0.1, 0.1, 0.1), wd2) * step(vec4(0.5, 0.5, 0.5, 0.5), irlv1);
    edr_l = step( lv2_cf*xbr2D_df(f,g), xbr2D_df(h,c) ) * irlv2l * edr;
    edr_u = step( lv2_cf*xbr2D_df(h,c), xbr2D_df(f,g) ) * irlv2u * edr;


    result.E=E; result.B=B; result.D=D; result.F=F; result.H=H;
    result.px=step(xbr2D_df(e,f),xbr2D_df(e,h));
    result.edri=edri; result.edr=edr; result.edr_l=edr_l; result.edr_u=edr_u;
    result.valid=true;
    return result;
}

vec3 resolve2DCell(Xbr2DCell c, vec2 local)
{
    vec2 fp=fract(local*TextureSize);
    vec4 fx=Ao*fp.y+Bo*fp.x, fx_l=Ax*fp.y+Bx*fp.x, fx_u=Ay*fp.y+By*fp.x;
    vec4 fx45i=c.edri*clamp((fx+delta-Co-Ci)/(2.0*delta),0.0,1.0);
    vec4 fx45=c.edr*clamp((fx+delta-Co)/(2.0*delta),0.0,1.0);
    vec4 fx30=c.edr_l*clamp((fx_l+delta_l-Cx)/(2.0*delta_l),0.0,1.0);
    vec4 fx60=c.edr_u*clamp((fx_u+delta_u-Cy)/(2.0*delta_u),0.0,1.0);
    vec4 maximum=max(max(fx30,fx60),max(fx45,fx45i));
    vec3 r1=mix(c.E,mix(c.H,c.F,c.px.x),maximum.x);
    r1=mix(r1,mix(c.B,c.D,c.px.z),maximum.z);
    vec3 r2=mix(c.E,mix(c.F,c.B,c.px.y),maximum.y);
    r2=mix(r2,mix(c.D,c.H,c.px.w),maximum.w);
    return mix(r1,r2,step(xbr2D_c_df(c.E,r1),xbr2D_c_df(c.E,r2)));
}

float filter2DStrength()
{
    return (pushConstants.filtering==10u || pushConstants.filtering==12u) ? 1.0 : 0.5;
}

vec3 filter2DReconstruct(vec2 local, bool topScreen)
{
    vec3 original=filter2DSource(local,topScreen).bgr;
    if (!filter2DCertified(filter2DSource(local,topScreen))) return original;
    Xbr2DCell c=analyze2DCell(local,topScreen);
    return c.valid ? mix(c.E,resolve2DCell(c,local),filter2DStrength()) : original;
}

vec3 apply2DOnlyFilter(vec2 uv, bool topScreen)
{
    vec2 local = screenLocalCoord(uv, topScreen);
    // Derivatives describe this screen's actual viewport, including layouts
    // with both screens, rather than assuming the whole Android surface.
    // Reconstruct pixel art on at least a 4x grid even at native 3D
    // resolution. A 2D-only game must not need a 4x 3D target for this.
    vec2 sourceSize = TextureSize * float(max(pushConstants.scale, 4u));
    vec2 displayScale = max(floor(1.0 / max(fwidth(local) * sourceSize, vec2(0.00001))), vec2(1.0));
    if (!filter2DCertified(filter2DSource(local, topScreen)))
        return sampleCompositeRgb(uv, topScreen);
    bool pixelAware = pushConstants.filtering == 9u || pushConstants.filtering == 10u;
    if (!pixelAware) return filter2DReconstruct(local, topScreen);

    // Sharp-bilinear grid correction (rsn8887/TheMaister, public domain),
    // applied AFTER reconstruction at the internal-resolution pixel grid.
    vec2 p = local * sourceSize;
    vec2 d = fract(p) - 0.5, region = 0.5 - 0.5 / displayScale;
    vec2 f = (d - clamp(d, -region, region)) * displayScale + 0.5;
    vec2 q = floor(p) + f - 0.5, base = floor(q), weight = fract(q);
    vec2 a = (base + vec2(0.5,0.5)) / sourceSize;
    vec2 b = (base + vec2(1.5,0.5)) / sourceSize;
    vec2 c = (base + vec2(0.5,1.5)) / sourceSize;
    vec2 e = (base + vec2(1.5,1.5)) / sourceSize;
    if (!filter2DCertified(filter2DSource(a,topScreen))
        || !filter2DCertified(filter2DSource(b,topScreen))
        || !filter2DCertified(filter2DSource(c,topScreen))
        || !filter2DCertified(filter2DSource(e,topScreen)))
        return filter2DReconstruct(local,topScreen);
    Xbr2DCell sa=analyze2DCell(a,topScreen);
    if (!sa.valid) return filter2DSource(local,topScreen).bgr;
    float strength=filter2DStrength();
    vec3 ca=mix(sa.E,resolve2DCell(sa,a),strength);
    if (all(lessThan(weight,vec2(0.0001)))) return ca;

    bool sameX=floor(a.x*TextureSize.x)==floor(b.x*TextureSize.x);
    bool sameY=floor(a.y*TextureSize.y)==floor(c.y*TextureSize.y);
    Xbr2DCell sb=sa;
    if (!sameX) sb=analyze2DCell(b,topScreen);
    Xbr2DCell sc=sa;
    if (!sameY) sc=analyze2DCell(c,topScreen);
    Xbr2DCell se=sb;
    if (!sameY) {
        if (sameX) se=sc;
        else se=analyze2DCell(e,topScreen);
    }
    // A mixed neighborhood stays entirely on the original renderer path.
    if (!sb.valid || !sc.valid || !se.valid) return filter2DSource(local,topScreen).bgr;
    vec3 cb=mix(sb.E,resolve2DCell(sb,b),strength);
    vec3 cc=mix(sc.E,resolve2DCell(sc,c),strength);
    vec3 ce=mix(se.E,resolve2DCell(se,e),strength);
    return mix(mix(ca,cb,weight.x),mix(cc,ce,weight.x),weight.y);
}

#undef TextureSize
#undef mul
