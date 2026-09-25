// Adapter for EXECUTING SELECTED MQL FUNCTION BODIES as C++.
// Not MT5: broker APIs, indicators and drawing/logging are fixture stubs.
#include <algorithm>
#include <cassert>
#include <cfloat>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <random>
#include <sstream>
#include <string>
#include <vector>
using string=std::string;
using datetime=long long;
using color=int;
template<class T> struct Array: std::vector<T> {
 using std::vector<T>::vector;
 T& operator[](int i){return this->at(i);}
 const T& operator[](int i)const{return this->at(i);}
};
template<class T> int ArraySize(const Array<T>& a){return (int)a.size();}
template<class T> int ArrayResize(Array<T>& a,int n,int reserve=0){a.resize(n);return n;}
template<class T> void ArraySetAsSeries(Array<T>&,bool){}
template<class A,class B> auto MathMax(A a,B b){return std::max<double>(a,b);}
template<class A,class B> auto MathMin(A a,B b){return std::min<double>(a,b);}
double MathAbs(double a){return std::abs(a);}
void ResetLastError(){}
int GetLastError(){return 0;}
template<class... T> string StringFormat(const string&,T...){return "";}
string DoubleToString(double x,int digits=5){return std::to_string(x);}
string IntegerToString(long x){return std::to_string(x);}
string TimeToString(datetime,int){return "";}
template<class... T> void Print(T...){}
void DebugPrint(string){}
void DebugError(string,string,int){}
void LogLifecycle(string){}
string PF(bool b){return b?"PASS":"FAIL";}
const int TIME_DATE=1,TIME_MINUTES=2,MAX_GRAPH_LINKS=16;
const double EMPTY_VALUE=DBL_MAX;
const double _Point=0.00001;
const int _Digits=5;
int h_atr=1,h_ema_fast=2,h_ema_slow=3;
Array<double> fixture_atr;
bool short_copy=false;
int CopyBuffer(int handle,int,int shift,int count,Array<double>& dest){
 int n=short_copy?count-1:count;
 dest.resize(std::max(0,n));
 for(int i=0;i<n;i++) dest[i]=(handle==h_atr?fixture_atr[i]:1.0);
 return n;
}
int InpSwingFractalN=2,InpOBLookback=20;
double InpDisplacementATR=1.1;
double g_str_last_high=0,g_str_last_low=0;
int g_str_high_origin=-1,g_str_low_origin=-1,g_str_trend=0,g_str_scanned_to=-1;
bool g_str_displacement=false;
bool InpUseRetestLifecycle=true,InpLogSignalDetails=false,DebugMode=false;
int InpRetestTimeoutBars=25,g_signal_count=0;
double g_atr=1,InpInvalidateBufferATR=.3,InpRetestMaxDistanceATR=2.5;
int PeriodSeconds(){return 300;}
int FindOBIndexByUID(string){return -1;}
bool IsSameIdeaAsBlacklisted(bool,double,double){return false;}
int blacklist_calls=0,signal_calls=0;
void BlacklistSetup(string,datetime){blacklist_calls++;}
void DrawPersistentSignal(bool,datetime,double,string){signal_calls++;}
Array<double> BufEmaFast,BufEmaSlow,BufVWAP;
bool g_ema_filled=false;
int g_vwap_closed_to=-1;
datetime g_vwap_anchor=0;
double g_cum_pv=0,g_cum_v=0;
datetime DayAnchor(datetime t){return t-t%86400;}
bool InpMergeFVG=true;

const string _Symbol="FIXTURE";
int InpZoneLookback=150,InpMaxZonesShown=3,InpFVGLookbackBars=100,InpMaxStrongOB=3;
double InpZoneBaseBodyATR=.6,InpZoneMaxHeightATR=2,InpFVGMinSizeATR=.3,InpOBMaxHeightATR=3;
bool InpAutoRemoveMitigatedOB=true,InpHideFilledFVG=true;
bool g_data_ready=true;
