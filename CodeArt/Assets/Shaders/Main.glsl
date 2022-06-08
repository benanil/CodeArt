#version 440
layout(local_size_x = 8, local_size_y = 8) in;
layout(binding = 0, rgba32f) writeonly uniform image2D img_output;

layout (std140, binding = 0) uniform DataBlock
{
	vec4 timeSizeScale;
};

#define INT_MAX  2147483647
#define INT_MIN -2147483647
#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38
#define PI 3.141592653

#define DEG_TO_RAD(deg) (deg * 0.017453292)
#define RAD_TO_DEG(rad) (rad * 57.29577951)
#define SPHERE_COUNT 2
#define PLANE_COUNT  1

const float SunDir = 1.0;
const float t_min = 0.001;
const float Epsilon = 0.0001;

// --- structures ---
struct Ray
{
	vec3 dir;
	vec3 origin;
};

struct Camera
{
	vec3 origin;
	vec3 lowerLeftCorner;
	vec3 horizontal;
	vec3 vertical;
};

struct HitRecord
{
	vec3 point;
	vec3 normal;
	float t;
	bool frontFace;
};

struct Sphere
{
	vec3 center;
	float radius;
	vec3 color;
	float roughness;
};

struct Plane
{
	vec3 center;
	vec3 normal;
	vec3 color;
	float roughness;	
};

struct TraceResult
{
	vec3 normal;
	vec3 color;
	bool shadowed;
	bool sky;
};

// --- Constructors ---

Plane CreatePlane(in vec3 center, in vec3 normal, in vec3 color, float roughness)
{
	Plane plane;
	plane.center	= center; 
	plane.normal	= normal;
	plane.color		= color;
	plane.roughness = roughness;
	return plane;
}

TraceResult CreateTraceResult(in vec3 normal, bool shadowed)
{
	TraceResult result;
	result.normal = normal;
	result.shadowed = shadowed;
	return result;
}

Sphere CreateSphere(in vec3 center, float radius)
{
	Sphere sphere;
	sphere.center = center;
	sphere.radius = radius;
	sphere.color  = vec3(.8, .65, .5);
	sphere.roughness = .8;
	return sphere;
}

Sphere CreateSphere(in vec3 center, float radius, in vec3 color, float roughness)
{
	Sphere sphere;
	sphere.center = center;
	sphere.radius = radius;
	sphere.color  = color;
	sphere.roughness = roughness;
	return sphere;
}

Ray CreateRay(vec3 origin, vec3 dir) 
{ 
	Ray ray;
	ray.origin = origin;
	ray.dir = dir;
	return ray;
}

Ray GetCameraRay(in Camera camera, vec2 uv)
{
	return CreateRay(camera.origin, camera.lowerLeftCorner + uv.x * camera.horizontal + uv.y * camera.vertical - camera.origin);
}

Camera CreateCamera()
{
	Camera camera;
    
	float aspectRatio = timeSizeScale.y / timeSizeScale.z;
	float focalLength = 1.0f;
    
	const float veiwportHeight = 2.0;
	const float veiwportWidth  = aspectRatio * veiwportHeight;
    
	camera.origin     = vec3(0.0 ,0.0, 0.0);
	camera.horizontal = vec3(veiwportWidth, 0.0, 0.0);
	camera.vertical   = vec3(0.0, veiwportHeight, 0.0);
	camera.lowerLeftCorner = camera.origin - camera.horizontal / 2.0 - camera.vertical / 2.0 - vec3(0, 0, focalLength);

	return camera;
}

// --- Helper ---
inline float LengthSquared(in vec3 vec)
{
	return vec.x * vec.x + vec.y * vec.y + vec.z * vec.z;
}

float GoldNoise(float seed, float x)
{
	const float _PHI = 1.618033988;
	return fract(tan(distance(x * _PHI, x) * fract(seed)) * x);
}

vec3 RandomInUnitSphere(float seed, float x)
{
	return vec3(GoldNoise(seed, x), GoldNoise(seed, x + 128), GoldNoise(seed, x + 256));
}

// --- Functions ---
vec3 Ray_At(in Ray ray, float t) { return ray.origin + (ray.dir * t); }

void SetFaceNormal(inout HitRecord record, in Ray ray, in vec3 outwardNormal)
{
	record.frontFace = dot(ray.dir, outwardNormal) < 0;
	record.normal = record.frontFace ? outwardNormal : -outwardNormal;   
}

bool SphereHitTest(in Sphere sphere, in Ray ray, float t_max)
{
	vec3 oc         = ray.origin - sphere.center;
	float a         = LengthSquared(ray.dir);
	float half_b    = dot(oc, ray.dir);
	float c         = LengthSquared(oc) - (sphere.radius * sphere.radius);
    
	float discriminant = half_b * half_b -  a * c;

	if (discriminant < 0) return false;

	float sqr = sqrt(discriminant);

	float root = (-half_b - sqr) / a;
	// Find the nearest root that lies in the acceptable range.
	if (root < t_min || t_max < root)
	{
		root = (-half_b + sqr) / a;
		if (root < t_min || t_max < root) return false;
	}
	return true;
}

bool Sphere_Hit(in Sphere sphere, in Ray ray, float t_max, out HitRecord record)
{
	vec3 oc         = ray.origin - sphere.center;
	float a         = LengthSquared(ray.dir);
	float half_b    = dot(oc, ray.dir);
	float c         = LengthSquared(oc) - (sphere.radius * sphere.radius);
    
	float discriminant = half_b * half_b -  a * c;

	if (discriminant < 0) return false;

	float sqr = sqrt(discriminant);

	float root = (-half_b - sqr) / a;
	// Find the nearest root that lies in the acceptable range.
	if (root < t_min || t_max < root)
	{
		root = (-half_b + sqr) / a;
		if (root < t_min || t_max < root) return false;
	}

	record.t = root;
	record.point = Ray_At(ray, root);
	vec3 outwardNormal = (record.point - sphere.center) / sphere.radius;
	SetFaceNormal(record, ray, outwardNormal);

	return true;
}

bool PlaneHit(in Plane plane, in Ray ray, float t_max, out HitRecord record)
{
	float denom = dot(plane.normal, ray.dir);
	
	if (abs(denom) > Epsilon)
	{
		record.t = dot(plane.center - ray.origin, plane.normal) / denom;
		record.normal = plane.normal;
		if (record.t >= 0)
		{
			record.point = Ray_At(ray, record.t);
			return true;
		}
	}

	return false;
}

const Sphere spheres[SPHERE_COUNT] =
{
	CreateSphere(vec3(0,0,-2)	  , 0.5, vec3(1.0, 1.0, 1.0), 0.7),
	CreateSphere(vec3(0,0,-2)	  , 0.5, vec3(1.0, 1.0, 1.0), 0.7),
	CreateSphere(vec3(0,-100.5,-1), 100, vec3(0.5, 0.8, 0.3), 0.0)
};

// Plane CreatePlane(in vec3 center, in vec3 normal, in vec3 color, float roughness)

const Plane Planes[2] =
{
	CreatePlane(vec3(0,0,0), vec3(0, 1, 0), vec3(0.6, 0.6, 0.6), 1.0),
	CreatePlane(vec3(0,0,0), vec3(0, 1, 0), vec3(0.6, 0.6, 0.6), 0.0)
};

bool CheckShadowed(in Ray ray)
{
	HitRecord record;
    
	for (int i = 0; i < SPHERE_COUNT; ++i)
		if (SphereHitTest(spheres[i], ray, FLT_MAX)) 
			return true;

	return false;
}

vec3 RayTraceReflect(in Ray ray) 
{
	HitRecord record;
    vec3 hitColor = vec3(1.0);

	float closestSoFar = FLT_MAX;
	bool hitAnything = false;

	for (int i = 0; i < SPHERE_COUNT; ++i)
	{
		if (Sphere_Hit(spheres[i], ray, closestSoFar, record)) 
		{
			hitAnything = true;
			hitColor = spheres[i].color;
			closestSoFar = record.t;
		}
	}
	
	if (hitAnything)
	{
	    const vec3 ToSunDir = -vec3(sin( timeSizeScale.x), cos( timeSizeScale.x), 0.0);
		const float bias = 0.01;
		vec3 color  = hitColor;
		vec3 normal = 0.5 * (record.normal + vec3(1,1,1));
	
		Ray hitPointToSun = CreateRay(record.point + (ToSunDir * bias), ToSunDir);
		bool shadowed = CheckShadowed(hitPointToSun); 
		color *= vec3(!shadowed); 
		return color;
	}
    
	vec3 unit_direction = normalize(ray.dir);
	float t = 0.5 * (unit_direction.y + 1.0);

	return 	mix(vec3(0.9, 0.9, 1.0), vec3(0.45, 0.6, 1.0), t); // sky color
}

TraceResult RayTrace(in Ray ray) 
{
	HitRecord record;
	float hitRoughness;
    vec3 hitColor = vec3(1.0);

	float closestSoFar = FLT_MAX;
	bool hitAnything = false;

	for (int i = 0; i < SPHERE_COUNT; ++i)
	{
		if (Sphere_Hit(spheres[i], ray, closestSoFar, record)) 
		{
			hitAnything = true;
			hitColor = spheres[i].color;
			hitRoughness = spheres[i].roughness;
			closestSoFar = record.t;
		}
	}

	TraceResult traceResult;

	if (hitAnything)
	{
	    const vec3 ToSunDir = -vec3(sin( timeSizeScale.x), cos( timeSizeScale.x), 0.0);
	    const vec3 SunDir   =  vec3(sin( timeSizeScale.x), cos( timeSizeScale.x), 0.0);
		const float bias = 0.01;
		traceResult.color = hitColor;
		traceResult.normal = 0.5 * (record.normal + vec3(1,1,1));
	
		Ray hitPointToSun = CreateRay(record.point + (ToSunDir * bias), ToSunDir);
		traceResult.shadowed = CheckShadowed(hitPointToSun); 
		Ray reflectRay = CreateRay(record.point, SunDir);
	 	traceResult.color = mix(hitColor, RayTraceReflect(reflectRay), hitRoughness);
		return traceResult;
	}
    
	traceResult.shadowed = false;
	vec3 unit_direction = normalize(ray.dir);
	float t = 0.5 * (unit_direction.y + 1.0);

	traceResult.color = mix(vec3(0.9, 0.9, 1.0), vec3(0.45, 0.6, 1.0), t);
	traceResult.sky = true;
	return traceResult;
}

float Repeat(float t, float len)
{
    return clamp(t - floor(t / len) * len, 0.0f, len);
}

void main()
{
	const vec2 uv = gl_GlobalInvocationID.xy / timeSizeScale.yz;
	Camera camera = CreateCamera();
	Ray ray = GetCameraRay(camera, uv);
	TraceResult traceResult = RayTrace(ray);
	if (!traceResult.sky)
	{
		float ndl = dot(traceResult.normal, -vec3(sin( timeSizeScale.x), cos( timeSizeScale.x), 0.0)); 
		traceResult.color *= ndl;
	}
	if (traceResult.shadowed)
	{
		traceResult.color *= vec3(0.5);
	}
	float gamma = 1.8;
	traceResult.color = pow(traceResult.color, vec3(1 / gamma));
	imageStore(img_output, ivec2(gl_GlobalInvocationID.xy), vec4(traceResult.color, 1.0) );
}