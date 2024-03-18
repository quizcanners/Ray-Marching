
void ClosestPointsOnTwoLines(float3 linePoint1, float3 lineVec1, float3 linePoint2, float3 lineVec2, out float3 closestPointLine1, out float3 closestPointLine2)
{
	float a = dot(lineVec1, lineVec1);
	float b = dot(lineVec1, lineVec2);
	float e = dot(lineVec2, lineVec2);

	float d = a*e - b*b;

	//lines are not parallel
	//if(d != 0.0f)

	float3 r = linePoint1 - linePoint2;
	float c = dot(lineVec1, r);
	float f = dot(lineVec2, r);

	float s = (b*f - c*e) / d;
	float t = (a*f - c*b) / d;

	closestPointLine1 = linePoint1 + lineVec1 * s;
	closestPointLine2 = linePoint2 + lineVec2 * t;
}

float DistanceBetweenLines(float3 r1, float3 r2, float3 x1, float3 x2)
{
	float3 u1 = r2 - r1;
	float3 u2 = x2 - x1;
	float3 u3 = cross(u1, u2);
	float3 s = r1 - x2;
	return abs(dot(s, u3) / (length(u3)+ 0.0001));
}

float FindDistanceToSegment(float3 pnt, float3 start, float3 end)
{
	float3 line_vec = end - start;
	float3 pnt_vec = pnt - start;
	float line_len = length(line_vec);
	float3 line_unitvec = normalize(line_vec);
	float3 pnt_vec_scaled = pnt_vec/line_len;
	float t = dot(line_unitvec, pnt_vec_scaled); 
				
	t = saturate(t);
				
	float3 nearest = line_vec * t;
	float dist = length(nearest - pnt_vec);
	nearest = nearest + start;
	return dist;
}

float DistanceToALineOneDirection(float3 ro, float3 rd, float3 pos)
{
	float3 toCenter = pos-ro;
	float isForward = smoothstep(-0.01, 0.01, dot(rd, toCenter));
	return length(lerp(toCenter, cross(rd, toCenter), isForward));
}

float DistanceToALine(float3 ro, float3 rd, float3 pos)
{
	return length(cross(rd, pos - ro));
}


float GetDistanceToSegment(float3 ro, float3 rd, float3 pos, float3 lineDirection, float3 LINE_LENGTH, float3 depthPoint, out float toDepth, out float fromCameraToLine)
{
		// Get points on the ray
		float rdDot = dot(rd, rd);
		float rayToLineDot = dot(rd, lineDirection);
		float lineDirectionDot = dot(lineDirection, lineDirection);

		float d = rdDot*lineDirectionDot - rayToLineDot*rayToLineDot + 0.000000001;

		float3 r = ro - pos;
		float c = dot(rd, r);
		float f = dot(lineDirection, r);

		float s = (rayToLineDot*f - c*lineDirectionDot) / d;
		float te = (rdDot*f - c*rayToLineDot) / d;

		float3 closestPointOnRay = ro + rd * s;
		float3 closestPointOnSegment = pos + lineDirection * te;

		

		// Calculate and points as spheres
		float3 lineVector = lineDirection * LINE_LENGTH;
		float3 startPos = pos - lineVector * 0.5;
		float3 endPos = pos + lineVector * 0.5;

		float3 cameraToStart_vec = startPos-ro;
		float is_StartForward = step(0, dot(rd, cameraToStart_vec));
		float toStart = length(lerp(cameraToStart_vec, cross(rd, cameraToStart_vec), is_StartForward));

		float3 cameraToEnd_vec = endPos-ro;
		float is_EndForward = step(0, dot(rd, cameraToEnd_vec));
		float toEnd = length(lerp(cameraToEnd_vec, cross(rd, cameraToEnd_vec), is_EndForward));

				
		// Clamp line
		float distanceToCenter = length(closestPointOnSegment - pos);
		float3 toLinePointVector = closestPointOnSegment-ro;
		float isForward = step(0, dot(rd, toLinePointVector));
		float distanceValid = smoothstep(LINE_LENGTH * 0.5, LINE_LENGTH * 0.499, distanceToCenter) * isForward;
		float rayToLine = length(closestPointOnRay-closestPointOnSegment);

		// Get Distance to camera
		float t = saturate(dot(lineDirection, -cameraToStart_vec/LINE_LENGTH)); 
		fromCameraToLine = length(lineVector * t + cameraToStart_vec);

		// Get Distance to LineStream
		float3 depthToStart_vec = startPos-depthPoint;
		t = saturate(dot(lineDirection, -depthToStart_vec/LINE_LENGTH)); 
		toDepth = length(lineVector * t + depthToStart_vec);

		float useDepth = smoothstep(-0.1,0.1, length(ro - closestPointOnSegment) - length(ro - depthPoint));

		// Combine all
		float combinedDistance = 
		min(
		min(toStart, toEnd),
		min(fromCameraToLine, lerp(1000, rayToLine, distanceValid)));


		// Fade by depth
		//float contactFade = 


		return  lerp(combinedDistance, toDepth, useDepth);
}
