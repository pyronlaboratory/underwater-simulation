/* Preprocessor directives for porting GLSL code to HLSL */
#define vec2 float2 
#define vec3 float3 
#define vec4 float4 
#define mat2 float2x2 
#define mat3 float3x3 
#define mat4 float4x4 

#define mod  fmod
#define mix  lerp
#define atan atan2

#define AA 3
#define ZERO (min(iFrame,0))
#define iFrame 50.0

cbuffer ModelViewProjectionConstantBuffer : register(b0)
{
	matrix model;
	matrix view;
	matrix projection;
	float4 timer;
	float4 iResolution;
};

struct PixelShaderInput
{
	float4 pos : SV_POSITION;
	float2 canvasXY : TEXCOORD0;
};

struct Ray
{
	float3 o; // origin 
	float3 d; // direction 
};

static float iTime = timer.x * 5.0;

// Copyright Inigo Quilez, 2013 - https://iquilezles.org/
// I am the sole copyright owner of this Work.
// You cannot host, display, distribute or share this Work neither
// as it is or altered, here on Shadertoy or anywhere else, in any
// form including physical and digital. You cannot use this Work in any
// commercial or non-commercial product, website or project. You cannot
// sell this Work and you cannot mint an NFTs of it or train a neural
// network with it without permission. I share this Work for educational
// purposes, and you can link to it, through an URL, proper attribution
// and unmodified screenshot, as part of your educational material. If
// these conditions are too restrictive please contact me and we'll
// definitely work it out.

// The source code for these videos from 2009: 
// https://www.youtube.com/watch?v=eKUh4nkmQbc
// https://www.youtube.com/watch?v=erS6SKqtXLY
//
// More info here: https://iquilezles.org/articles/mandelbulb
//
// See https://www.shadertoy.com/view/MdfGRr to see the Julia counterpart



// https://iquilezles.org/articles/intersectors
vec2 isphere(in vec4 sph, in vec3 ro, in vec3 rd)
{
	vec3 oc = ro - sph.xyz;
	float b = dot(oc, rd);
	float c = dot(oc, oc) - sph.w * sph.w;
	float h = b * b - c;
	if (h < 0.0) return vec2(-1.0, -1.0);
	h = sqrt(h);
	return -b + vec2(-h, h);
}

// https://iquilezles.org/articles/mandelbulb
float map(in vec3 p, out vec4 resColor)
{
	vec3 w = p;
	float m = dot(w, w);

	vec4 trap = vec4(abs(w), m);
	float dz = 1.0;

	for (int i = 0; i < 4; i++)
	{
		// trigonometric version

		// dz = 8*z^7*dz
		dz = 8.0 * pow(m, 3.5) * dz + 1.0;

		// z = z^8+c
		float r = length(w);
		float b = 8.0 * acos(w.y / r);
		float a = 8.0 * atan2(w.x, w.z);
		w = p + pow(r, 8.0) * vec3(sin(b) * sin(a), cos(b), sin(b) * cos(a));        

		trap = min(trap, vec4(abs(w), m));

		m = dot(w, w);
		if (m > 256.0)
			break;
	}

	resColor = vec4(m, trap.yzw);

	// distance estimation (through the Hubbard-Douady potential)
	return 0.25 * log(m) * sqrt(m) / dz;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal(in vec3 pos, in float t, in float px)
{
	vec4 tmp;
	vec2 e = vec2(1.0, -1.0) * 0.5773 * 0.25 * px;
	return normalize(e.xyy * map(pos + e.xyy, tmp) +
		e.yyx * map(pos + e.yyx, tmp) +
		e.yxy * map(pos + e.yxy, tmp) +
		e.xxx * map(pos + e.xxx, tmp));
}

// https://iquilezles.org/articles/rmshadows
float softshadow(in vec3 ro, in vec3 rd, in float k)
{
	float res = 1.0;
	float t = 0.0;
	for (int i = 0; i < 64; i++)
	{
		vec4 kk;
		float h = map(ro + rd * t, kk);
		res = min(res, k * h / t);
		if (res < 0.001) break;
		t += clamp(h, 0.01, 0.2);
	}
	return clamp(res, 0.0, 1.0);
}

float raycast(in vec3 ro, in vec3 rd, out vec4 rescol, in float px)
{
	float res = -1.0;

	// bounding sphere
	vec2 dis = isphere(vec4(0.0, 0.0, 0.0, 1.25), ro, rd);
	if (dis.y < 0.0) return -1.0;
	dis.x = max(dis.x, 0.0);
	dis.y = min(dis.y, 10.0);

	// raymarch fractal distance field
	vec4 trap;

	float t = dis.x;
	for (int i = 0; i < 128; i++)
	{
		vec3 pos = ro + rd * t;
		float th = 0.25 * px * t;
		float h = map(pos, trap);
		if (t > dis.y || h < th) break;
		t += h;
	}

	if (t < dis.y)
	{
		rescol = trap;
		res = t;
	}

	return res;
}

const vec3 light1 = vec3(0.577, 0.577, -0.577);
const vec3 light2 = vec3(-0.707, 0.000, 0.707);

vec3 refVector(in vec3 v, in vec3 n)
{
	// return v;
	float k = dot(v, n);
	return (k>0.0) ? v : -v;
	// return (k > 0.0) ? v : v - 2.0 * n * k;
}

vec3 render(Ray ray, in vec2 p, in mat4 cam)
{
	// ray setup
	const float fle = 0.07; // 1.5

	vec2  sp = (2.0 * p - iResolution.xy) / iResolution.y;
	float px = 2.0 / (iResolution.y * fle);

	vec3  ro = vec3(cam[0].w, cam[1].w, cam[2].w);
	vec3  rd = normalize((mul(cam,vec4(sp, fle, 0.0))).xyz);

	// intersect fractal
	vec4 tra;
	float t = raycast(ro, rd, tra, px);

	vec3 col;

	// color sky
	if (t < 0.0)
	{
		// col = vec3(0.0, 0.0, 0.0);
		return col;
		
		col = vec3(0.8, .9, 2.1) * (0.6 + 0.4 * rd.y);
		col += 5.0 * vec3(0.8, 0.7, 0.5) * pow(clamp(dot(rd, light1), 0.0, 1.0), 32.0);
	}
	
	// color fractal
	else
	{
		// color
		col = vec3(0.01, 0.01, 0.01);
		col = mix(col, vec3(0.10, 0.20, 0.30), clamp(tra.y, 0.0, 1.0));
		col = mix(col, vec3(0.02, 0.10, 0.30), clamp(tra.z * tra.z, 0.0, 1.0));
		col = mix(col, vec3(0.30, 0.10, 0.02), clamp(pow(tra.w, 6.0), 0.0, 1.0));
		col *= 0.5;

		// lighting terms
		vec3  pos = ro + t * rd;
		vec3  nor = calcNormal(pos, t, px);

		nor = refVector(nor, -rd);

		vec3  hal = normalize(light1 - rd);
		vec3  ref = reflect(rd, nor);
		float occ = clamp(0.05 * log(tra.x), 0.0, 1.0);
		float fac = clamp(1.0 + dot(rd, nor), 0.0, 1.0);

		// sun
		float sha1 = softshadow(pos + 0.001 * nor, light1, 32.0);
		float dif1 = clamp(dot(light1, nor), 0.0, 1.0) * sha1;
		float spe1 = pow(clamp(dot(nor, hal), 0.0, 1.0), 32.0) * dif1 * (0.04 + 0.96 * pow(clamp(1.0 - dot(hal, light1), 0.0, 1.0), 5.0));
		// bounce
		float dif2 = clamp(0.5 + 0.5 * dot(light2, nor), 0.0, 1.0) * occ;
		// sky
		float dif3 = (0.7 + 0.3 * nor.y) * (0.2 + 0.8 * occ);

		vec3 lin = vec3(0.0, 0.0, 0.0);
		lin += 12.0 * vec3(1.50, 1.10, 0.70) * dif1;
		lin += 4.0 * vec3(0.25, 0.20, 0.15) * dif2;
		lin += 1.5 * vec3(0.10, 0.20, 0.30) * dif3;
		lin += 2.5 * vec3(0.35, 0.30, 0.25) * (0.05 + 0.95 * occ);
		lin += 4.0 * fac * occ;
		col *= lin;
		col = pow(col, vec3(0.7, 0.9, 1.0));
		col += spe1 * 15.0;
	}

	// gamma
	col = pow(col, vec3(0.4545, 0.4545, 0.4545));

	// vignette
	col *= 1.0 - 0.05 * length(sp);

	return col;
}

void mainImage(Ray ray, out vec4 fragColor, in vec2 fragCoord)
{
	float time = 0.0; // iTime * .1;

	// camera
	float di = 1.4 + 0.1 * cos(.29 * time);
	vec3  ro = di * vec3(cos(.33 * time), 0.8 * sin(.37 * time), sin(.31 * time));
	vec3  ta = vec3(0.0, 0.1, 0.0);
	float cr = 0.5 * cos(0.1 * time);

	// camera matrix
	vec3 cp = vec3(sin(cr), cos(cr), 0.0);
	vec3 cw = normalize(ta - ro);
	vec3 cu = normalize(cross(cw, cp));
	vec3 cv = (cross(cu, cw));
	mat4 cam = mat4(cu, ro.x, cv, ro.y, cw, ro.z, 0.0, 0.0, 0.0, 1.0);

	// render
	vec3 col = vec3(0.0, 0.0, 0.0);
	for (int j = ZERO; j < AA; j++)
		for (int i = ZERO; i < AA; i++)
		{
			col += render(ray, fragCoord + (vec2(i, j) / float(AA)), cam);
		}
	col /= float(AA * AA);

	fragColor = vec4(col, 1.0);
}


float4 main(PixelShaderInput input) : SV_Target
{
	// specify primary ray: 
	Ray ray;

	// set ray direction in view space 
	float dist2Imageplane = 5.0;
	float3 viewDir = float3(input.canvasXY, -dist2Imageplane);
	viewDir = normalize(viewDir);

	ray.o = float3(0, 0, 15);
	ray.d = viewDir;

	float4 fragColor;

	mainImage(ray, fragColor, input.pos.xy);
	return fragColor;
}
