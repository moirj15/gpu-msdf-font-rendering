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
}

void UpdateDistances(float d, float3 edgeColor, inout float3 distances,
    out EdgeColors outEdgeColors)
{
  if (edgeColor.r != 0 && CMP(d, distances.r) < 0)
  {
    distances.r = d;
    outEdgeColors.red = edgeColor;
  }
  if (edgeColor.g != 0 && CMP(d, distances.g) < 0)
  {
    distances.g = d;
    outEdgeColors.green = edgeColor;
  }
  if (edgeColor.b != 0 && CMP(d, distances.b) < 0)
  {
    distances.b = d;
    outEdgeColors.blue = edgeColor;
  }
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

float LinearEdgeSignedDistance(float2 P, LinearBezier edge)
{
  float2 sgnFirstTerm = P - edge.p0;
  float2 sgnSecondTerm = edge.p1 - edge.p0;
  float2 sgn = sign(cross2D(sgnFirstTerm, sgnSecondTerm));
  float t = dot(sgnFirstTerm, sgnSecondTerm) / dot(sgnSecondTerm, sgnSecondTerm);
  float2 segment;
  if (t > 0.5)
  {
    segment = edge.p1 - P;
  }
  else
  {
    segment = edge.p0 - P;
  }
  return sgn * length(segment);
}

// Ported from the msdfgen library

int solveQuadratic(float x[2], float a, float b, float c)
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

int solveCubicNormed(float x[3], float a, float b, float c)
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

int solveCubic(float x[3], float a, float b, float c, float d)
{
  if (a != 0)
  {
    float bn = b / a;
    if (abs(bn) < 1e6) // Above this ratio, the numerical error gets larger than if we treated a as zero
      return solveCubicNormed(x, bn, c / a, d / a);
  }
  return solveQuadratic(x, b, c, d);
}

float2 QuadraticDirection(float param, QuadraticBezier e)
{
  float2 tangent = lerp(e.p1 - e.p0, e.p2 - e.p1, param);
  if (!tangent)
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
  float distance = length((p[2] - P)); // distance from B
  if (distance < abs(minDistance))
  {
    epDir = QuadraticDirection(1, edge);
    minDistance = sign(cross2D(epDir, p[2] - P)) * distance;
    param = dot(P - edge.p1, epDir) / dot(epDir, epDir);
  }
  for (int i = 0; i < solutions; ++i)
  {
    if (t[i] > 0 && t[i] < 1)
    {
      float2 qe = qa + 2 * t[i] * ab + t[i] * t[i] * br;
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
  if (!tangent)
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
    float distance = (p[3] - length(P)); // distance from B
    if (distance < abs(minDistance))
    {
      epDir = CubicDirection(1, e);
      minDistance = sign(cross2D(epDir, p[3] - P)) * distance;
      param = dot(epDir - (p[3] - P), epDir) / dot(epDir, epDir);
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


float3 GetFinalValues(
    float3 linearDistances,
    EdgeColors linearEdgeColors,
    float3 quadraticDistances,
    EdgeColors quadraticEdgeColors,
    float3 cubicDistances,
    EdgeColors cubicEdgeColors)
{
  float inf = 1.0f / 0.0f;
  float3 distances = { inf, inf, inf };
  EdgeColors colors;

  if (CMP(linearDistances.r, distances.r) < 0)
  {
    distances.r = linearDistances.r;
    colors.red = linearEdgeColors.red;
  }
  if (CMP(linearDistances.g, distances.g) < 0)
  {
    distances.g = linearDistances.g;
    colors.green = linearEdgeColors.green;
  }
  if (CMP(linearDistances.b, distances.b) < 0)
  {
    distances.b = linearDistances.b;
    colors.blue = linearEdgeColors.blue;
  }
  
  return distances;
}

float3 GeneratePixelGPU(float2 P)
{
  float3 linearDistances = { 0, 0, 0 };
  EdgeColors linearEdgeColors = { };
  float3 quadraticDistances = { 0, 0, 0 };
  EdgeColors quadraticEdgeColors = { };
  float3 cubicDistances = { 0, 0, 0 };
  EdgeColors cubicEdgeColors = { };
  uint linearEdgesSize = 0;
  uint quadraticEdgesSize = 0;
  uint cubicEdgesSize = 0;
  uint stride = 0;
  
  linearEdges.GetDimensions(linearEdgesSize, stride);
  quadraticEdges.GetDimensions(quadraticEdgesSize, stride);
  cubicEdges.GetDimensions(cubicEdgesSize, stride);

  for (int i = 0; i < linearEdgesSize; i++)
  {
    LinearBezier edge = linearEdges[i];
    float3 edgeColor = UnpackColor(edge.color);
    float d = LinearEdgeSignedDistance(P, edge);
    UpdateDistances(d, edgeColor, linearDistances, linearEdgeColors);
    edge.color = PackColor(edgeColor);
  }

  for (int i = 0; i < quadraticEdgesSize; i++)
  {
    QuadraticBezier edge = quadraticEdges[i];
    float3 edgeColor = UnpackColor(edge.color);
    float d = QuadraticEdgeSignedDistance(P, edge);
    UpdateDistances(d, edgeColor, quadraticDistances, quadraticEdgeColors);
    edge.color = PackColor(edgeColor);
  }

  for (int i = 0; i < cubicEdgesSize; i++)
  {
    CubicBezier edge = cubicEdges[i];
    float3 edgeColor = UnpackColor(edge.color);
    float d = CubicEdgeSignedDistance(P, edge);
    UpdateDistances(d, edgeColor, cubicDistances, cubicEdgeColors);
    edge.color = PackColor(edgeColor);
  }

  float3 closestDistances = { };

  float3 edgeColors = GetFinalValues(
        linearDistances,
        linearEdgeColors,
        quadraticDistances,
        quadraticEdgeColors,
        cubicDistances,
        cubicEdgeColors);

  float3 distances = EdgeSignedPseudoDistance(P, edgeColors);
  return distanceColor(distances);
}

void CSMain()
{
  
}