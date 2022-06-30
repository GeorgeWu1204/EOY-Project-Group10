#ifndef ROVER_DRIVE_H
#define ROVER_DRIVE_H

void roverBegin();

void roverStop();

void roverWait();

void roverTranslate(float v);

void roverRotate(float omega);

void roverTranslateToTarget(float rtarget, float v);

void roverRotateToTarget(float phitarget, float omega);

void roverRotateBack(float omega);

void roverMoveToTarget(float xTarget, float yTarget, float v, float omega);

void roverLookAtTarget(float xTarget, float yTarget, float omega);

float getRoverX();

float getRoverY();

float getRoverTheta(bool degrees);

float getRoverR();

float getRoverPhi(bool degrees);

void roverResetGlobalCoords();

void roverSetGlobalCoords(float xSet, float ySet, float thetaSet);

float roverDetectRadar();

float roverGetSOC();

#endif
