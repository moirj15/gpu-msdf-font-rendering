#define M_PI       3.14159265358979323846   // pi
struct LinearBezier
{
  uint color;
  float2 p0;
  float2 p1;
};

struct QuadraticBezier
{
  uint color;
  float2 p0;
  float2 p1;
  float2 p2;
};

struct CubicBezier
{
  uint color;
  float2 p0;
  float2 p1;
  float2 p2;
  float2 p3;
};

StructuredBuffer<LinearBezier> linearEdges : register(t0);
StructuredBuffer<QuadraticBezier> quadraticEdges : register(t1);
StructuredBuffer<CubicBezier> cubicEdges : register(t2);

struct EdgeColors
{
  float3 red;
  float3 green;
  float3 blue;
};

bool CMP(float d, float distance)
{
#if 1 
  //bool r = false;
  if (abs(d) == abs(distance) && sign(d) > 0.0)
    return true;
			
  return abs(d) < abs(distance);
#else
	return abs(d) < abs(distance);
	//return abs(d) - abs(distance) < 0.0;
#endif
}


float PseudoDistance(float2 P, float2 a, float2 b, float t, float dist)
{
  if (t > 0.0 || t < 1.0) 
    return dist;
  float2 ab = normalize(b - a);
  float2 aq = P - a;
  float2 ortho = float2(-ab.y, ab.x);
  return dot(aq, ortho);
}

void UpdateDistances(float d, float3 edgeColor, inout float3 distances, float t /*, LinearBezier e*/, float2 P,
    out LinearBezier closestEdge[3])
{
  //outEdgeColors = (EdgeColors) 0;
	/*
	if (abs(d) < abs(distances.r)) {
		//closest = d;
		distances = d.rrr; //(float)i / 32.0;
	}*/
  //float pseudoDist = PseudoDistance(P, e.p0, e.p1, t, d);
  
  if (edgeColor.r != 0 && CMP(d, distances.r))
  {
    distances.r = d;
    //closestEdge[0] = e;
    //distances.r = pseudoDist;

    //outEdgeColors.red = edgeColor;
  }

  if (edgeColor.g != 0 && CMP(d, distances.g))
  {
    distances.g = d;

    //closestEdge[1] = e;
    //distances.g = pseudoDist;

    //outEdgeColors.green = edgeColor;
  }
  if (edgeColor.b != 0 && CMP(d, distances.b))
  {
    distances.b = d;

    //closestEdge[2] = e;
    //distances.b = pseudoDist;

    //outEdgeColors.blue = edgeColor;
  }
}

bool NegCMP(float d, float distance)
{
  return abs(d) < abs(distance);
  //return d < distance;
	//return abs(d) - abs(distance) < 0.0;
}

void UpdateDistancesNegative(float d, float3 edgeColor, inout float3 negativeDistances //,
    /*out EdgeColors outEdgeColors*/)
{
  //outEdgeColors = (EdgeColors) 0;
	/*
	if (abs(d) < abs(distances.r)) {
		//closest = d;
		distances = d.rrr; //(float)i / 32.0;
	}*/

  
///*
  if (edgeColor.r != 0 && NegCMP(d, negativeDistances.r))
  {
    negativeDistances.r = d;
    //outEdgeColors.red = edgeColor;
  }

  if (edgeColor.g != 0 && NegCMP(d, negativeDistances.g))
  {
    negativeDistances.g = d;
    //outEdgeColors.green = edgeColor;
  }
  if (edgeColor.b != 0 && NegCMP(d, negativeDistances.b))
  {
    negativeDistances.b = d;
    //outEdgeColors.blue = edgeColor;
  }
//*/
}

float3 UnpackColor(uint c)
{
  return float3(
    float((c >> 24) & 0xff) / 255.0,
    float((c >> 16) & 0xff) / 255.0,
    float((c >> 8) & 0xff) / 255.0);
}

uint PackColor(float3 c)
{
  return uint(c.r * 255.0) << 24 | uint(c.g * 255.0) << 16 | uint(c.b * 255.0) << 8;
}

float cross2D(float2 a, float2 b)
{
  return a.x * b.y - a.y * b.x;
}

float LinearEdgeSignedDistance(float2 P, LinearBezier edge, out float t)
{
  float2 sgnFirstTerm = P - edge.p0;
  float2 sgnSecondTerm = edge.p1 - edge.p0;
  float sgn = sign(cross2D(sgnFirstTerm, sgnSecondTerm));
  t = (dot(sgnFirstTerm, sgnSecondTerm) / dot(sgnSecondTerm, sgnSecondTerm));
  float2 segment;
  if (t > 0.5)
  {
    segment = edge.p1 - P;
  }
  else
  {
    segment = edge.p0 - P;
  }

	//return sgn * length(segment);

  float2 ab = edge.p1 - edge.p0;
  float2 ap = P - edge.p0;

  t = (dot(ap, ab) / dot(ab, ab));
	//if (tt == 0.0) tt = 1.0;
  float2 cp = edge.p0 + saturate(t) * ab;
	
  float dist = distance(P, cp);
  float det = ab.x * ap.y - ab.y * ap.x;
	//float det = dot(ab, ap);
  float s = (det >= 0.0) ? 1.0 : -1.0;
  return dist * s;
#if 0
	float2 ab = edge.p1 - edge.p0;
	 t = dot(P - edge.p0, ab) / dot(ab, ab);
	float2 closest = edge.p0 + saturate(t) * ab;
	float d = distance(P, closest);
	float det = ab.x * (P.y - edge.p0.y) - ab.y * (P.x - edge.p0.x);
	float s = det >= 0 ? d : -d;
	return s;
#endif  
  return sgn * length(segment);
}

// Ported from the msdfgen library

int solveQuadratic(inout float x[2], float a, float b, float c)
{
    // a == 0 -> linear equation
  if (a == 0 || abs(b) > 1e12 * abs(a))
  {
        // a == 0, b == 0 -> no solution
    if (b == 0)
    {
      if (c == 0)
        return -1; // 0 == 0
      return 0;
    }
    x[0] = -c / b;
    return 1;
  }
  float dscr = b * b - 4 * a * c;
  if (dscr > 0)
  {
    dscr = sqrt(dscr);
    x[0] = (-b + dscr) / (2 * a);
    x[1] = (-b - dscr) / (2 * a);
    return 2;
  }
  else if (dscr == 0)
  {
    x[0] = -b / (2 * a);
    return 1;
  }
  else
    return 0;
}

int solveCubicNormed(inout float x[3], float a, float b, float c)
{
  float a2 = a * a;
  float q = 1 / 9. * (a2 - 3 * b);
  float r = 1 / 54. * (a * (2 * a2 - 9 * b) + 27 * c);
  float r2 = r * r;
  float q3 = q * q * q;
  a *= 1 / 3.;
  if (r2 < q3)
  {
    float t = r / sqrt(q3);
    if (t < -1)
      t = -1;
    if (t > 1)
      t = 1;
    t = acos(t);
    q = -2 * sqrt(q);
    x[0] = q * cos(1 / 3. * t) - a;
    x[1] = q * cos(1 / 3. * (t + 2 * M_PI)) - a;
    x[2] = q * cos(1 / 3. * (t - 2 * M_PI)) - a;
    return 3;
  }
  else
  {
    float u = (r < 0 ? 1 : -1) * pow(abs(r) + sqrt(r2 - q3), 1 / 3.);
    float v = u == 0 ? 0 : q / u;
    x[0] = (u + v) - a;
    if (u == v || abs(u - v) < 1e-12 * abs(u + v))
    {
      x[1] = -.5 * (u + v) - a;
      return 2;
    }
    return 1;
  }
}

int solveCubic(inout float x[3], float a, float b, float c, float d)
{
  if (a != 0)
  {
    float bn = b / a;
    if (abs(bn) < 1e6) // Above this ratio, the numerical error gets larger than if we treated a as zero
      return solveCubicNormed(x, bn, c / a, d / a);
  }
  return solveQuadratic((float[2]) x, b, c, d);
}

float2 QuadraticDirection(float param, QuadraticBezier e)
{
  float2 tangent = lerp(e.p1 - e.p0, e.p2 - e.p1, param);
  if (!tangent.x && !tangent.y)
    return e.p2 - e.p0;
  return tangent;
}

float QuadraticEdgeSignedDistance(float2 P, QuadraticBezier edge)
{
  float2 qa = edge.p0 - P;
  float2 ab = edge.p1 - edge.p0;
  float2 br = edge.p2 - edge.p1 - ab;
  float a = dot(br, br);
  float b = 3 * dot(ab, br);
  float c = 2 * dot(ab, ab) + dot(qa, br);
  float d = dot(qa, ab);
  float t[3];
  int solutions = solveCubic(t, a, b, c, d);

  float2 epDir = QuadraticDirection(0, edge);
  float minDistance = sign(cross2D(epDir, qa)) * length(qa); // distance from A
  float param = -dot(qa, epDir) / dot(epDir, epDir);
  float distance = length((edge.p2 - P)); // distance from B
  if (distance < abs(minDistance))
  {
    epDir = QuadraticDirection(1, edge);
    minDistance = sign(cross2D(epDir, edge.p2 - P)) * distance;
    param = dot(P - edge.p1, epDir) / dot(epDir, epDir);
  }
  for (int i = 0; i < solutions; ++i)
  {
    if (t[i] > 0 && t[i] < 1)
    {
      float2 qe = qa + 2.0 * t[i] * ab + t[i] * t[i] * br;
      float distance = length(qe);
      if (distance <= abs(minDistance))
      {
        minDistance = sign(cross2D(ab + t[i] * br, qe)) * distance;
        param = t[i];
      }
    }
  }

  //if (param >= 0 && param <= 1)
  //  return SignedDistance(minDistance, 0);
  //if (param < .5)
  //  return SignedDistance(minDistance, abs(dot(direction(0).normalize(), qa.normalize())));
  //else
  //  return SignedDistance(minDistance, abs(dot(direction(1).normalize(), (p[2] - P).normalize())));
  return minDistance;
}

float2 CubicDirection(float param, CubicBezier e)
{
  float2 tangent = lerp(lerp(e.p1 - e.p0, e.p2 - e.p1, param), lerp(e.p2 - e.p1, e.p3 - e.p2, param), param);
  if (!tangent.x && !tangent.y)
  {
    if (param == 0)
      return e.p2 - e.p0;
    if (param == 1)
      return e.p3 - e.p1;
  }
  return tangent;
}

#define MSDFGEN_CUBIC_SEARCH_STARTS 4
#define MSDFGEN_CUBIC_SEARCH_STEPS 4

float CubicEdgeSignedDistance(float2 P, CubicBezier e)
{
  float2 qa = e.p0 - P;
  float2 ab = e.p1 - e.p0;
  float2 br = e.p2 - e.p1 - ab;
  float2 as = (e.p3 - e.p2) - (e.p2 - e.p1) - br;

  float2 epDir = CubicDirection(0, e);
  float minDistance = sign(cross2D(epDir, qa)) * length(qa); // distance from A
  float param = -dot(qa, epDir) / dot(epDir, epDir);
    {
    float distance = length((e.p2 - P)); // distance from B
    if (distance < abs(minDistance))
    {
      epDir = CubicDirection(1, e);
      minDistance = sign(cross2D(epDir, e.p3 - P)) * distance;
      param = dot(epDir - (e.p3 - P), epDir) / dot(epDir, epDir);
    }
  }
    // Iterative minimum distance search
  for (int i = 0; i <= MSDFGEN_CUBIC_SEARCH_STARTS; ++i)
  {
    float t = 1. / MSDFGEN_CUBIC_SEARCH_STARTS * i;
    float2 qe = qa + 3 * t * ab + 3 * t * t * br + t * t * t * as;
    float2 d1 = 3 * ab + 6 * t * br + 3 * t * t * as;
    float2 d2 = 6 * br + 6 * t * as;
    float improvedT = t - dot(qe, d1) / (dot(d1, d1) + dot(qe, d2));
    if (improvedT > 0 && improvedT < 1)
    {
      int remainingSteps = MSDFGEN_CUBIC_SEARCH_STEPS;
      do
      {
        t = improvedT;
        qe = qa + 3 * t * ab + 3 * t * t * br + t * t * t * as;
        d1 = 3 * ab + 6 * t * br + 3 * t * t * as;
        if (!--remainingSteps)
          break;
        d2 = 6 * br + 6 * t * as;
        improvedT = t - dot(qe, d1) / (dot(d1, d1) + dot(qe, d2));
      } while (improvedT > 0 && improvedT < 1);
      float distance = length(qe);
      if (distance < abs(minDistance))
      {
        minDistance = sign(cross2D(d1, qe)) * distance;
        param = t;
      }
    }
  }

  return minDistance;
  //if (param >= 0 && param <= 1)
  //  return SignedDistance(minDistance, 0);
  //if (param < .5)
  //  return SignedDistance(minDistance, abs(dot(direction(0).normalize(), qa.normalize())));
  //else
  //  return SignedDistance(minDistance, abs(dot(direction(1).normalize(), (p[3] - P).normalize())));
}


void GetFinalValues(
    float3 linearDistances,
    float3 quadraticDistances,
    float3 cubicDistances,
    out float3 finalDistances)
{
  finalDistances = float3(1000.0, 1000.0, 1000.0);

  if (CMP(linearDistances.r, finalDistances.r))
  {
    finalDistances.r = linearDistances.r;
  }
  if (CMP(linearDistances.g, finalDistances.g))
  {
    finalDistances.g = linearDistances.g;
  }
  if (CMP(linearDistances.b, finalDistances.b))
  {
    finalDistances.b = linearDistances.b;
  }

  if (CMP(quadraticDistances.r, finalDistances.r))
  {
    finalDistances.r = quadraticDistances.r;
  }
  if (CMP(quadraticDistances.g, finalDistances.g))
  {
    finalDistances.g = quadraticDistances.g;
  }
  if (CMP(quadraticDistances.b, finalDistances.b))
  {
    finalDistances.b = quadraticDistances.b;
  }
  
  if (CMP(cubicDistances.r, finalDistances.r))
  {
    finalDistances.r = cubicDistances.r;
  }
  if (CMP(cubicDistances.g, finalDistances.g))
  {
    finalDistances.g = cubicDistances.g;
  }
  if (CMP(cubicDistances.b, finalDistances.b))
  {
    finalDistances.b = cubicDistances.b;
  }
}


float3 GeneratePixelGPU(float2 P)
{
  float3 linearDistances = { 1000.0, 1000.0, 1000.0 };
  float3 nearestNegative = { -1000.0, -1000.0, -1000.0 };
  EdgeColors linearEdgeColors = (EdgeColors) 0;
  float3 quadraticDistances = { 1000.0, 1000.0, 1000.0 };
  EdgeColors quadraticEdgeColors = (EdgeColors) 0;
  float3 cubicDistances = { 1000.0, 1000.0, 1000.0 };
  EdgeColors cubicEdgeColors = (EdgeColors) 0;
  uint linearEdgesSize = 0;
  uint quadraticEdgesSize = 0;
  uint cubicEdgesSize = 0;
  uint stride = 0;
  
  float3 totalDistances = { 1000.0, 1000.0, 1000.0 };

  linearEdges.GetDimensions(linearEdgesSize, stride);
  quadraticEdges.GetDimensions(quadraticEdgesSize, stride);
  cubicEdges.GetDimensions(cubicEdgesSize, stride);
  float closest = 1000.0;
  float t = 0;
  LinearBezier closestEdges[3];

  float globalMin = 10000.0;
  float globalSign = 1.0;
#if 1
  for (uint i = 0; i < linearEdgesSize; i++)
  {
    LinearBezier edge = linearEdges[i];
    float3 edgeColor = UnpackColor(edge.color);
    float d = LinearEdgeSignedDistance(P, edge, t);
    /*
	if (abs(d) < abs(closest)) {
		closest = d;
		linearDistances = closest;//(float)i / 32.0;
	}*/
	//if (sign(d) > 0.0)
    UpdateDistances(d, edgeColor, totalDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    
    UpdateDistances(d, edgeColor, linearDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    if (sign(d) < 0.0)
      UpdateDistancesNegative(d, edgeColor, nearestNegative /*, linearEdgeColors*/);

    //linearDistances = min(d, linearDistances.r).rrr;
    //edge.color = PackColor(edgeColor);
    //if (i == 0)
    //  return linearDistances;
    if (CMP(d, globalMin))
    {
      globalMin = d;
      globalSign = sign(d);
    }
  }
	
#endif 
/* 
  if (abs(linearDistances.x) > abs(nearestNegative.x))
	linearDistances.x = nearestNegative.x;
  if (abs(linearDistances.y) > abs(nearestNegative.y))
	linearDistances.y = nearestNegative.y;
  if (abs(linearDistances.z) > abs(nearestNegative.z))
	linearDistances.z = nearestNegative.z;
*/
	//return abs(nearestNegative) * 8.0;
//float PseudoDistance(float2 P, float2 a, float2 b, float t, float dist)

  totalDistances.r = PseudoDistance(P, closestEdges[0].p0, closestEdges[0].p1, t, totalDistances.r);
  totalDistances.g = PseudoDistance(P, closestEdges[1].p0, closestEdges[1].p1, t, totalDistances.g);
  totalDistances.b = PseudoDistance(P, closestEdges[2].p0, closestEdges[2].p1, t, totalDistances.b);
  //return t;

#if 1 
  for (uint j = 0; j < quadraticEdgesSize; j++)
  {
    QuadraticBezier edge = quadraticEdges[j];
    float3 edgeColor = UnpackColor(edge.color);
    float d = QuadraticEdgeSignedDistance(P, edge);
    UpdateDistances(d, edgeColor, quadraticDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    UpdateDistances(d, edgeColor, totalDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    
    edge.color = PackColor(edgeColor);
    if (CMP(d, globalMin))
    {
      globalMin = d;
      globalSign = sign(d);
    }
  }
#endif
  totalDistances.r = PseudoDistance(P, closestEdges[0].p0, closestEdges[0].p1, t, totalDistances.r);
  totalDistances.g = PseudoDistance(P, closestEdges[1].p0, closestEdges[1].p1, t, totalDistances.g);
  totalDistances.b = PseudoDistance(P, closestEdges[2].p0, closestEdges[2].p1, t, totalDistances.b);
#if 1
  for (uint k = 0; k < cubicEdgesSize; k++)
  {
    CubicBezier edge = cubicEdges[k];
    float3 edgeColor = UnpackColor(edge.color);
    float d = CubicEdgeSignedDistance(P, edge);
    //UpdateDistances(d, edgeColor, cubicDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    UpdateDistances(d, edgeColor, totalDistances, t /*, edge*/, P, closestEdges /*, linearEdgeColors*/);
    if (CMP(d, globalMin))
    {
      globalMin = d;
      globalSign = sign(d);
    }

    edge.color = PackColor(edgeColor);
  }
  totalDistances.r = PseudoDistance(P, closestEdges[0].p0, closestEdges[0].p1, t, totalDistances.r);
  totalDistances.g = PseudoDistance(P, closestEdges[1].p0, closestEdges[1].p1, t, totalDistances.g);
  totalDistances.b = PseudoDistance(P, closestEdges[2].p0, closestEdges[2].p1, t, totalDistances.b);
#endif
  //return linearDistances * 8.0;
  //return (linearDistances, quadraticDistances) * 8.0;
  //return quadraticDistances * 8.0;

  //return cubicDistances * 8.0;
#if 1  
  if (totalDistances.r * globalSign < 0.0) 
    totalDistances.r *= -1.0;
  if (totalDistances.g * globalSign < 0.0) 
    totalDistances.g *= -1.0;
  if (totalDistances.b * globalSign < 0.0) 
    totalDistances.b *= -1.0;
#endif  
  float3 finalDistances = float3(1000.0, 1000.0, 1000.0);
  EdgeColors finalColors;

  GetFinalValues(
        linearDistances,
        quadraticDistances,
        cubicDistances,
         finalDistances);
	//return max(linearDistances, quadraticDistances) * 8.0;
  return totalDistances * 8.0;
  //float3 distances = EdgeSignedPseudoDistance(P, edgeColors);
  //return distanceColor(distances);
	//return ((linearDistances + (quadraticDistances * -1.0)) / 2.0); * 8.0;
  //rCreturn finalDistances * 8.0;
}

RWTexture2D<float4> output;

static const float2 pxRange = { 1920.0 / 32.0, 1080.0 / 32.0 };

[numthreads(8, 8, 1)]
void CSMain(uint3 threadID : SV_DispatchThreadID)
{
  float2 P = -0.125 + ((threadID.xy /*+ 0.5*/) / 32.0) * 1.0;
  //output[threadID.xy] = float4(GeneratePixelGPU(threadID.xy / float2(32, 32)) / float3(32, 32, 32) + 0.5, 1.0);
  //output[threadID.xy] = float4(GeneratePixelGPU(P), 1.0);
  float3 c = GeneratePixelGPU(P);

  float ur = 4 * (1.0 / 32.0);
  //float ur = pxRange.x * (1.0 / 32.0);

  //output[threadID.xy] = float4(c / ur + 0.5, 1.0);
  output[threadID.xy] = float4(c, 1.0);
  
  uint linearEdgesSize = 0;
  uint stride = 0;
  linearEdges.GetDimensions(linearEdgesSize, stride);
  for (uint i = 0; i < linearEdgesSize; i++)
  {
    //output[linearEdges[i].p0 * 32.0 + 0.125] = float4(1.0, 0.0, 0.0, 1.0);
  }

}