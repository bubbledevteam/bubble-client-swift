//
//  SmoothValue.c
//  Calsta
//
//  Created by yan on 2021/4/10.
//

#include "SmoothValue.h"

double Sum(double* data, int size) {
    double sum = 0;
    for (int i = 0; i < size; i++)
    sum = sum + data[i];
    return sum;
}

double Mean(double* data, int size) {
    return Sum(data, size) / size;
}

// population variance 总体方差
double POP_Variance(double* data, int size) {
    double variance = 0;
    for (int i = 0; i < size; i++) {
        
        variance = variance + pow((data[i] - Mean(data, size)), 2);
    }
    variance = variance / size;
    return variance;
}

// population standard deviation 总体标准差
double POP_STD_dev(double* data, int size) {
    double std_dev;
    std_dev = sqrt(POP_Variance(data, size));
    return std_dev;
}

//sample variance 样本方差
double Sample_Variance(double* data, int size) {
    double variance = 0;
    for (int i = 0; i < size; i++) {
        variance = variance + pow((data[i] - Mean(data, size)), 2);
    }
    variance = variance / (size - 1);
    return variance;
}

// sample standard deviation 样本标准差
double Sample_STD_dev(double* data, int size) {
    double std_dev;
    std_dev = sqrt(Sample_Variance(data, size));
    return std_dev;
}


static double influence = 0.5f;
static double threshold_1 = 4.5f;
static double roc_threshold_1 = 5.5f;
static double threshold_2 = 1.0f;
static double roc_threshold_2 = 3.5f;

long long seconds(long long value) {
    return value / 1000;
}

///smoothValue
/// @param current 当前oop值
/// @param list 上一个值
/// @param size list size
double smoothValue(struct C_BgReading current, struct C_BgReading *list, int size) {
    if (size < 5) {
        return current.raw_data;
    }
    struct C_BgReading before = list[0];
    struct C_BgReading before2 = list[1];
    double datas[5];
    for (int i = 0; i < size; i++) {
        datas[i] = list[i].raw_data;
    }

    double avgRawData = Mean(datas, size);//前5个血糖值的平均值
    double stdRawData = Sample_STD_dev(datas, size);
    double min=seconds(current.timestamp - before.timestamp) / 60.0;
    double roc = fabs((current.raw_data - before.raw_data) /
            (min));//filteredY smooth值
    double roc2 = fabs((current.raw_data - 2.0 * before.raw_data + before2.raw_data) /
            (seconds(current.timestamp - before.timestamp) / 60.0) /
            (seconds(current.timestamp - before.timestamp) / 60.0));
    int cond_1 = (fabs(current.raw_data - avgRawData) > threshold_1 * stdRawData) && (roc > roc_threshold_1);
    int cond_2 = (roc2 > threshold_2) && (roc > roc_threshold_2);
    int signals;
    double value;
    if (cond_1 || cond_2) {
        if (current.raw_data > avgRawData) {
            signals = 1;
        } else {
            signals = -1;
        }

        value = influence * current.raw_data + (1 - influence) * before.raw_data;
        
    } else {
        signals = 0;
        value = current.raw_data;
    }
    
    return value;
}

double smoothValue1(double value, struct C_BgReading *list, int size) {
    if (size < 5) {
        return value;
    }
    
    double smoothValue = 0;
    int index = 0;
    for (int i = 0; i < size; i++) {
        struct C_BgReading bgReading = list[i];
        int x = 0;
        if (index == 0) {
            x = 219;
        } else if (index == 1) {
            x = -6;
        } else if (index == 2) {
            x = -6;
        } else if (index == 3) {
            x = 9;
        } else if (index == 4) {
            x = -3;
        }
        if (x != 0) {
            smoothValue += bgReading.raw_data * x;
        }
        index++;
    }
    smoothValue += value * 207;
    smoothValue = smoothValue / 420;
    
    return smoothValue;
}
