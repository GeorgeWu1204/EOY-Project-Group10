#ifndef ROVER_DRIVE_H
#define ROVER_DRIVE_H

void roverBegin();

void roverStop();

void roverWait();

void roverTranslate(float v);

void roverRotate(float omega);

void roverTranslateToTarget(float rtarget, float v);

void roverRotateToTarget(float phitarget, float omega);

void roverSlowRotate(float omega);

void roverSlowRotateBack(float omega);

#endif