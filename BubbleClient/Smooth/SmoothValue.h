//
//  SmoothValue.h
//  Calsta
//
//  Created by yan on 2021/4/10.
//

#ifndef SmoothValue_h
#define SmoothValue_h

#include <stdio.h>
#include <math.h>

struct C_BgReading {
    double raw_data;
    long long timestamp;
};

double smoothValue(struct C_BgReading current, struct C_BgReading *list, int size);
double smoothValue1(double value, struct C_BgReading *list, int size);

#endif /* SmoothValue_h */
