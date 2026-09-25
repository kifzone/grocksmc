// Deterministic synthetic fixtures; no profitability/market-frequency claims.
struct Bars {
 Array<double> o,h,l,c;
 Array<datetime> t;
 Array<long> v;
 Bars(int n):o(n),h(n),l(n),c(n),t(n),v(n,10){}
};
Bars fixture(int n,int seed=17){
 Bars b(n); std::mt19937 rng(seed); double price=100;
 fixture_atr.resize(n);
 for(int i=0;i<n;i++){
  double step=((int)(rng()%2001)-1000)/500.0;
  if(i%29==0) step*=5; // include impulsive breaks, not only weak random walks
  b.o[i]=price; b.c[i]=price+step;
  b.h[i]=std::max(b.o[i],b.c[i])+.1+(rng()%100)/100.0;
  b.l[i]=std::min(b.o[i],b.c[i])-.1-(rng()%100)/100.0;
  b.t[i]=1700000000LL+i*300; b.v[i]=10+rng()%100;
  // prior-only ATR surrogate: fixture API, not MT5 ATR verification
  double sum=0; int from=std::max(0,i-13);
  for(int k=from;k<=i;k++) sum+=b.h[k]-b.l[k];
  fixture_atr[i]=sum/(i-from+1); price=b.c[i];
 }
 return b;
}
void reset_structure(){
 g_structures.clear(); g_str_scanned_to=-1;
 g_str_last_high=g_str_last_low=0;g_str_trend=0;
 g_str_displacement=false;g_str_high_origin=g_str_low_origin=-1;
}
void scan(const Bars& b,int total,bool full){
 DetectStructure(total,b.o,b.h,b.l,b.c,b.t,full?-1:0);
}
string structure_digest(int cutoff=2147483647){
 std::ostringstream out; out<<std::setprecision(17);
 for(const auto& e:g_structures){
  if(e.bar>cutoff)continue;
  out<<e.bar<<'|'<<e.time<<'|'<<e.price<<'|'<<e.bullish<<'|'<<e.type<<'|'
     <<e.ob_bar<<'|'<<e.strength<<'|'<<e.priority<<'|'<<e.confirmation_time<<'|'
     <<e.availability_time<<'|'<<e.swing_origin<<'|'<<e.swing_confirmation_bar<<'|'
     <<e.swing_availability_time<<'|'<<e.displacement_atr<<';';
 }
 return out.str();
}
void causality(){
 int events=0,mss=0;
 for(int seed=0;seed<20;seed++){
  auto b=fixture(600,seed); reset_structure(); scan(b,600,true);
  for(auto e:g_structures){
   events++;
   assert(e.time<=e.confirmation_time && e.confirmation_time==e.availability_time);
   assert(e.availability_time==b.t[e.bar+1]);
   assert(e.swing_origin>=InpSwingFractalN);
   assert(e.swing_confirmation_bar==e.swing_origin+InpSwingFractalN);
   assert(e.swing_availability_time<=e.time);
   if(e.type=="MSS"){mss++;assert(e.displacement_atr>=InpDisplacementATR);}
  }
 }
 assert(events>100 && mss>0);
 std::cout<<"PASS selected structure chronology / current-break MSS evidence: "<<events<<" events, "<<mss<<" MSS\n";
 // Partial copies must not advance scan state or append events.
 auto b=fixture(100);reset_structure();short_copy=true;scan(b,100,true);
 assert(g_structures.empty() && g_str_scanned_to==-1 && !g_data_ready);short_copy=false;g_data_ready=true;
 std::cout<<"PASS short ATR copy rejects selected structure scan\n";
}
void replay(){
 for(int seed=0;seed<6;seed++){
  auto b=fixture(350,seed); reset_structure();
  std::vector<string> incremental;
  for(int total=8;total<=350;total++){
   scan(b,total,false);
   incremental.push_back(structure_digest()+std::to_string(g_str_trend)+
      std::to_string(g_str_last_high)+std::to_string(g_str_last_low));
  }
  for(int total=8;total<=350;total++){
   reset_structure();scan(b,total,true);
   assert(incremental[total-8]==structure_digest()+std::to_string(g_str_trend)+
      std::to_string(g_str_last_high)+std::to_string(g_str_last_low));
  }
 }
 std::cout<<"PASS selected structure prefix full/incremental equivalence: 2058 prefixes\n";
}
void future_mutation(){
 for(int seed=0;seed<10;seed++){
  auto b=fixture(600,seed); auto original_atr=fixture_atr;
  reset_structure();scan(b,502,true);string frozen=structure_digest(500);
  assert(!frozen.empty());
  // bar 501 is live at decision 500: change ALL OHLCV at 501+ but not its
  // known open timestamp (availability). Change fixture ATR future too.
  auto changed=b;
  for(int j=501;j<600;j++){
   changed.o[j]=10000+j;changed.h[j]=20000+j;
   changed.l[j]=1;changed.c[j]=15000+j;changed.v[j]=999999;
   fixture_atr[j]=100000+j;
  }
  reset_structure();scan(changed,502,true);assert(frozen==structure_digest(500));
  reset_structure();scan(changed,600,true);assert(frozen==structure_digest(500));
  fixture_atr=original_atr;
  reset_structure();scan(b,600,true);assert(frozen==structure_digest(500));
 }
 std::cout<<"PASS selected structure future mutation at bar 500: 10 seeds\n";
}
void seed_setup(int created){
 g_atr=1; // isolate lifecycle evidence from previous zone fixtures
 g_trade_setup=STradeSetup{};g_active_setup=SActiveSetup{};
 g_active_setup.active=true;g_active_setup.state="READY";g_active_setup.is_buy=true;
 g_active_setup.created_bar=created;g_active_setup.created_time=1000+(created+1)*300;
 g_active_setup.zone_bottom=99;g_active_setup.zone_top=101;g_active_setup.entry=100;
 g_active_setup.sl=95;g_active_setup.tp3=110;g_active_setup.confirmed_bar=-1;
 g_active_setup.ob_index_cache=-1;
 blacklist_calls=signal_calls=0;
}
void lifecycle(){
 Bars b(30);
 for(int i=0;i<30;i++){b.o[i]=99.5;b.c[i]=100.5;b.h[i]=101;b.l[i]=99;b.t[i]=1000+i*300;}
 seed_setup(4);
 ManageSetupLifecycle(6,b.o,b.h,b.l,b.c,b.t,true);
 assert(g_active_setup.state=="READY" && signal_calls==0); // seed bar cannot confirm
 b.c[6]=1000000; b.h[6]=1000001; b.l[6]=0;
 ManageSetupLifecycle(7,b.o,b.h,b.l,b.c,b.t,false);
 assert(g_active_setup.state=="READY" && signal_calls==0); // tick is not evidence
 ManageSetupLifecycle(7,b.o,b.h,b.l,b.c,b.t,true);
 assert(g_active_setup.state=="CONFIRMED" && signal_calls==1 && g_trade_setup.valid);
 assert(g_active_setup.confirmed_time==b.t[6]);
 ManageSetupLifecycle(7,b.o,b.h,b.l,b.c,b.t,false);
 assert(signal_calls==1);
 // retirement cannot leave stale valid output
 b.c[6]=100;b.h[6]=111;b.l[6]=98;
 ManageSetupLifecycle(8,b.o,b.h,b.l,b.c,b.t,true);
 assert(!g_active_setup.active && !g_trade_setup.valid && blacklist_calls==1);
 // Even on a new bar after half the timeout, a forming extreme is not evidence.
 seed_setup(4);b.c[19]=1000000;b.h[19]=1000001;
 ManageSetupLifecycle(20,b.o,b.h,b.l,b.c,b.t,true);
 assert(g_active_setup.active && g_active_setup.state=="CONFIRMED" && blacklist_calls==0);
 // live distance cannot invalidate after elapsed half-timeout
 InpRetestTimeoutBars=2;seed_setup(1);g_active_setup.created_time=b.t[2];
 b.c[4]=1000000;
 ManageSetupLifecycle(5,b.o,b.h,b.l,b.c,b.t,true);
 // elapsed=3 > timeout; legitimately expires. Separate tick must not expire.
 seed_setup(1);
 ManageSetupLifecycle(5,b.o,b.h,b.l,b.c,b.t,false);
 assert(g_active_setup.active && blacklist_calls==0);
 InpRetestTimeoutBars=25;
 std::cout<<"PASS selected lifecycle availability, tick immutability, confirmation and retirement\n";
}
void fvg_identity(){
 g_fvgs.clear(); Array<double> h(20,100),l(20,90);
 SFVG a{}; a.bar=3;a.top=98;a.bottom=95;a.bullish=true;a.state="OPEN";
 AddOrMergeFVG(a,20,h,l);AddOrMergeFVG(a,20,h,l);assert(g_fvgs.size()==1);
 SFVG b=a;b.bar=8;b.top=99;b.bottom=96;
 AddOrMergeFVG(b,20,h,l);assert(g_fvgs.size()==2 && g_fvgs[0].top==98);
 InpMergeFVG=false;AddOrMergeFVG(b,20,h,l);assert(g_fvgs.size()==2);
 std::cout<<"PASS FVG origin dedup and immutable geometry with merge on/off\n";
}
void vwap(){
 auto b=fixture(700);b.t[0]=86400-600;
 for(int i=1;i<700;i++)b.t[i]=b.t[0]+i*300;
 BufEmaFast.resize(700);BufEmaSlow.resize(700);BufVWAP.resize(700);
 g_vwap_closed_to=-1;g_ema_filled=false;
 for(int total=3;total<=700;total++)FillEMAAndVWAP(total,b.o,b.h,b.l,b.c,b.t,b.v,true);
 auto inc=BufVWAP;
 auto pv=g_cum_pv,vv=g_cum_v;
 b.c[699]+=10;b.h[699]+=10;
 FillEMAAndVWAP(700,b.o,b.h,b.l,b.c,b.t,b.v,false);
 assert(g_cum_pv==pv && g_cum_v==vv);
 g_vwap_closed_to=-1;g_ema_filled=false;
 FillEMAAndVWAP(700,b.o,b.h,b.l,b.c,b.t,b.v,true);
 double sum=0,vol=0;datetime day=-1;
 for(int i=0;i<699;i++){
  if(DayAnchor(b.t[i])!=day){day=DayAnchor(b.t[i]);sum=vol=0;}
  sum+=(b.h[i]+b.l[i]+b.c[i])/3*b.v[i];vol+=b.v[i];
  assert(std::abs(BufVWAP[i]-inc[i])<1e-10);
  assert(std::abs(BufVWAP[i]-sum/vol)<1e-10);
 }
 std::cout<<"PASS historical daily VWAP independent oracle, full/incremental and tick immutability\n";
}

void historical_zones(){
 Bars b(14);fixture_atr.resize(14,1);
 for(int i=0;i<14;i++){
  b.t[i]=1000+i*300;b.o[i]=99;b.c[i]=99.1;b.h[i]=99.5;b.l[i]=98.5;
  fixture_atr[i]=1;
 }
 b.o[12]=99;b.c[12]=104;b.h[12]=105;b.l[12]=99;
 g_zones.clear();DetectZones(14,b.o,b.h,b.l,b.c,b.t);
 assert(g_zones.size()==1 && g_zones[0].bar==12);
 const auto initial=g_zones[0];
 // Original bug: atr[total-1] controls historical zone acceptance.
 fixture_atr[13]=.001;b.h[13]=10000;b.l[13]=.001;
 g_zones.clear();DetectZones(14,b.o,b.h,b.l,b.c,b.t);
 assert(g_zones.size()==1 && g_zones[0].top==initial.top && g_zones[0].bottom==initial.bottom);
 // OB geometry must depend on break ATR, not current g_atr or live wick.
 g_structures.clear();SStructureBreak e{};e.bar=12;e.ob_bar=10;e.bullish=true;e.strength=4;
 g_structures.push_back(e);g_order_blocks.clear();g_atr=100;
 // Before the structure confirmed, bar 11 crosses the eventual OB; not a retest.
 b.l[11]=98.7;b.c[11]=99;b.l[12]=100;
 DetectOrderBlocks(14,b.o,b.h,b.l,b.c,b.t);
 assert(g_order_blocks.size()==1 && g_order_blocks[0].state=="ACTIVE");
 const auto ob=g_order_blocks[0];
 g_order_blocks.clear();g_atr=.00001;b.l[13]=99;
 DetectOrderBlocks(14,b.o,b.h,b.l,b.c,b.t);
 assert(g_order_blocks.size()==1 && g_order_blocks[0].top==ob.top && g_order_blocks[0].state=="ACTIVE");
 short_copy=true;g_order_blocks.clear();g_zones.clear();g_fvgs.clear();
 DetectOrderBlocks(14,b.o,b.h,b.l,b.c,b.t);
 DetectZones(14,b.o,b.h,b.l,b.c,b.t);
 DetectFVG(14,b.o,b.h,b.l,b.c,b.t);
 assert(g_order_blocks.empty() && g_zones.empty() && g_fvgs.empty() && !g_data_ready);short_copy=false;g_data_ready=true;
 std::cout<<"PASS historical zone/OB ATR, no live/pre-availability OB touch, short-copy rejection\n";
}
int main(int argc,char** argv){
 string group=argc>1?argv[1]:"all";
 if(group=="all" || group=="causality")causality();
 if(group=="all" || group=="replay"){replay();vwap();}
 if(group=="all" || group=="no_lookahead"){future_mutation();historical_zones();}
 if(group=="all" || group=="engine"){lifecycle();fvg_identity();}
}
