// v5.8.0 P1 signal-engine input wiring; v5.7.1 causal audit remains applicable.
// NOT a validated predictive/replay engine. Legacy notes below are historical.
//+------------------------------------------------------------------+
//| QuantumSMC_AI_Pro_v5.4.0_Stable.mq5                              |
//| Premium SMC Analysis - STABLE BUILD (P0/P1/P2 Upgrade)            |
//| Based on v5.3.0 Fixed - all architectural leaks fixed            |
//|                                                                    |
//| FIXES v5.3.0 (Audit):                                             |
//| 1. Chronological arrays enforced via ArrayGetAsSeries()           |
//| 2. Structure/mitigations ONLY on closed bars (RETEST live only)    |
//| 3. Stable UID for OBs & Setups                                    |
//| 4. Master arrays NEVER sorted in-place; index tables used         |
//| 5. Blacklist prevents re-seeding INVALID setup                    |
//| 6. Fallback zone with min ATR height                              |
//| 7. ObjectsDeleteAll restricted to New Bar (delta)                 |
//| 8. ArrayResize with reserve + incremental EMA/VWAP                |
//|                                                                    |
//| UPGRADE v5.4.0 STABLE (P0/P1/P2):                                  |
//| P0.1 Guard total<3 / total-2, P0.2 Timeout+Distance invalidation  |
//| P0.3 Re-evaluate FVG after merge, P0.4 Enhanced SetupId+Blacklist |
//| P1.5 Incremental Detection, P1.6 Smart Object Mgmt, P1.7 Static   |
//|     price buffers, P1.8 Strict array caps (30/40/25/20)            |
//| P2.9 Sweep displacement/volume filter, P2.10 Synthetic zone       |
//|     quality, P2.11 Simplified Graph, P2.12 Lifecycle logs          |
//|                                                                    |
//| ============ AUDIT PASS - v5.4.1 CORRECTIONS ================    |
//| See the accompanying audit notes for full detail. Summary of      |
//| fixes applied in this build:                                      |
//|                                                                    |
//| [CRITICAL / COMPILE-BREAKING] Every array-typed parameter in the  |
//| main FORWARD DECLARATIONS block was written as a scalar reference |
//| (e.g. "const double&") instead of an array reference              |
//| (e.g. "const double &[]"). In MQL5 these are different parameter  |
//| types, so every forward declaration mismatched its real           |
//| definition - this does not compile ("function already defined     |
//| with a different type"/parameter mismatch on every one of ~30     |
//| functions). Fixed by adding [] to every array parameter in the    |
//| forward-declared signatures (structs-by-reference and true        |
//| scalar out-parameters were correctly left without []).            |
//|                                                                    |
//| [CRITICAL / FUNCTIONAL] DetectOrderBlocks() was never called from |
//| the incremental branch of OnCalculate. Since InpUseIncrementalDete|
//| ction defaults to true, and the incremental branch runs on every  |
//| single new-bar event once the first full rebuild has happened,    |
//| this meant g_order_blocks[] was populated ONCE on the very first  |
//| bar and never again for the rest of the session/backtest. Every   |
//| subsequent structure break (BOS/CHoCH/MSS) got an ob_bar index    |
//| but no matching SOrderBlock was ever created for it - so entry OB |
//| selection, the entry-OB highlight, and the whole SETUP lifecycle  |
//| silently stopped finding new opportunities after bar 1. Fixed by  |
//| calling DetectOrderBlocks() in the incremental branch right after |
//| DetectStructure(), matching the full-rebuild branch. Its existing |
//| IsDuplicateOB() guard already makes repeated calls safe (it only  |
//| appends genuinely new blocks), so this is a pure addition, not a  |
//| behavior change to the rest of the pipeline.                      |
//|                                                                    |
//| [PERFORMANCE / CONTRACT VIOLATION] DetectStructure/DetectZones/   |
//| DetectFVG/DetectLiquidity always rescanned their FULL lookback     |
//| window (e.g. total-InpZoneLookback .. lastClosed) on every single  |
//| incremental call, not just the newly closed bar(s). That directly  |
//| contradicts the file's own "P1.5 Incremental Detection" claim and  |
//| means CPU cost still scales with total history length on every    |
//| tick, exactly like the "full rebuild" path it was meant to avoid.  |
//| Fixed by adding an optional scan-lower-bound parameter (default    |
//| -1 = old full-window behavior, used by the full-rebuild branch)    |
//| and having the incremental branch pass a tight recent-bar window   |
//| (a handful of bars back from the newly closed bar) instead.        |
//| Existing dedup guards (bar-based for structure, IsDuplicateOB /    |
//| IsDuplicateLiquidity for OB/liquidity, and the FVG merge path)     |
//| make this safe: nothing outside the tighter window was reachable   |
//| in a single-new-bar increment anyway, since a bar's own detectors  |
//| only ever look at that bar and a small fixed lookback around it.   |
//|                                                                    |
//| ============ SIGNAL ENGINE REPAIR - v5.7.0 =====================   |
//| Root causes fixed (see audit notes delivered with this build):     |
//|  R1  OnCalculate fell into the FULL REBUILD branch on every tick    |
//|      that was not a new bar (useIncremental required is_new_bar),   |
//|      so every tick wiped g_structures/OBs/FVGs and re-ran the       |
//|      decision engine with live-bar data.                            |
//|  R2  CalculateAITradeSetup() replaced g_active_setup whenever the    |
//|      candidate SetupId differed. The id embeds the zone, and the     |
//|      zone follows live price (OB distance ranking / synthetic zone   |
//|      centred on price), so READY/RETEST/CONFIRMED setups were        |
//|      overwritten tick after tick -> "signal appears then vanishes". |
//|  R3  The CONFIRMED alert was only de-duplicated by bar time, so it   |
//|      re-fired on every new bar while the signal stayed valid.       |
//|  R4  Incremental DetectStructure restarted with trend=0 and an      |
//|      empty swing memory on a 12-bar tail -> missed / mislabelled    |
//|      BOS/CHoCH/MSS. Full scan also used a fractal N bars before it  |
//|      was confirmable (look-ahead). Now one causal state machine.    |
//|  R5  Incremental path never re-checked liquidity sweeps of pools    |
//|      detected earlier, never refreshed HTF bias / dealing range /   |
//|      Judas / kill zones, and duplicated breakers on every bar.      |
//|  R6  ComputeHTFBias cached dh[0] (the OLDEST D1 bar of the lookback) |
//|      as PDH/PDL/PDC -> wrong PDH/PDL lines, pivots, camarilla, TPs.  |
//|  R7  EMA incremental CopyBuffer used start_pos=total-3 (the oldest  |
//|      bars); VWAP cumulative sums were incremented on every tick.    |
//|  R8  Stale chart objects: SmartObjectCleanup used a wrong OB name   |
//|      pattern, never removed STR_/LIQ_/ZN_/BRK_ labels or ENTRY/SL/   |
//|      TP lines after a setup retired; DrawTextLabel never updated.   |
//|  R9  Setups seeded from a structure older than the retest timeout    |
//|      were created, instantly invalidated and blacklisted; fuzzy      |
//|      blacklist had no expiry -> engine silently locked.             |
//|  R10 New: DebugMode prints a PASS/FAIL table per gate with the      |
//|      exact rejection reason; CopyBuffer failures are reported.      |
//|  R11 Confirmed signals now leave a persistent, never-moved arrow    |
//|      (QSMCSIG_ prefix) so history stays consistent after refresh.   |
//|                                                                    |
//| ============ AUDIT PASS - v5.8.0 P1 DEAD INPUTS ==============    |
//| P1.1 ROOT: InpUseBinarySearch never reached SelectEntryOB; nearest  |
//|      price alone cannot replace the direction/strength OB ranking.  |
//| FIX: binary nearest in a sorted INDEX anchors a max-distance range; |
//|      apply the original filters/score to every candidate in range.  |
//|      Input=false uses the original linear scan. Ties keep the       |
//|      oldest master index; no OB/Setup ID or master order changes.    |
//| P1.2 ROOT: InpUseBitMasking was ignored; every check used bit ops.  |
//| FIX: true uses compact mask and O(1) pattern tests; false stores   |
//|      boolean factors and checks requested factors without bit ops.  |
//|      False is clearer but checks up to 12 flags per pattern; the    |
//|      dashboard/logs identify the path (no misleading zero mask).    |
//| P1.3 ROOT: InpMinRightConfirmBars was only printed on the panel.   |
//| FIX: the latest BOS/CHoCH/MSS must age by that many ADDITIONAL     |
//|      CLOSED bars after the break (0 = immediate after break close)  |
//|      before its mask bit or setup factors/levels can be used. Both  |
//|      rebuild and incremental paths use total-2; pending events     |
//|      cannot seed or replace a setup. Detection/drawing, existing   |
//|      lifecycle, alerts, IDs and PFX/SIGPFX are unchanged.          |
//| Local fixture/static checks cover P1 paths; MetaEditor compile and |
//| MT5 visual/tester comparison still require a terminal (not here).  |
//+------------------------------------------------------------------+
#property copyright "Quantum SMC v5.8.0 P1 Signal Engine Inputs"
#property version   "5.80"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_label1  "EMA Fast"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1
#property indicator_label2  "EMA Slow"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2
#property indicator_label3  "VWAP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_width3  1
#property indicator_style3  STYLE_DOT

double BufEmaFast[], BufEmaSlow[], BufVWAP[];

//====================================================================
// ENUMS
//====================================================================
enum ENUM_MIN_GRADE
{
   GRADE_D = 1, // D (accept everything)
   GRADE_C = 2, // C
   GRADE_B = 3, // B
   GRADE_A = 4, // A
   GRADE_APLUS = 5 // A+ only
};

//====================================================================
// INPUTS
//====================================================================
input group "====== EMA & VWAP ======"
input int InpEMAFast = 50;
input int InpEMASlow = 200;
input group "====== Oscillators ======"
input int InpATRPeriod = 14;
input int InpADXPeriod = 14;
input int InpRSIPeriod = 14;
input group "====== Structure (BOS/CHoCH/MSS) ======"
input int InpSwingFractalN = 3;
input int InpMaxStructureShown = 6;
input double InpDisplacementATR = 1.1;
input group "====== Order Blocks ======"
input int InpOBLookback = 20;
input int InpMaxStrongOB = 3;
input bool InpAutoRemoveMitigatedOB = true;
input int InpOBTransparency = 88;
input double InpOBMaxHeightATR = 3.0;
input group "====== Demand / Supply Zones ======"
input int InpZoneLookback = 150;
input int InpMaxZonesShown = 3;
input double InpZoneBaseBodyATR = 0.6;
input double InpZoneMaxHeightATR = 2.0;
input group "====== Breaker Blocks ======"
input bool InpShowBreakers = true;
input int InpMaxBreakersShown = 2;
input group "====== Fair Value Gaps ======"
input int InpFVGLookbackBars = 100;
input double InpFVGMinSizeATR = 0.3;
input int InpMaxFVGShown = 3;
input bool InpMergeFVG = true;
input bool InpHideFilledFVG = true;
input group "====== Liquidity ======"
input int InpLiquidityLookback = 100;
input int InpLiquidityFractalN = 2;
input double InpLiqToleranceATR = 0.15;
input double InpLiquidityTolerancePips = 5.0;
input int InpMaxLiquidityShown = 3;
input group "====== Premium Features ======"
input bool InpShowKillZones = true;
input bool InpShowSessionHL = true;
input group "====== Sessions & Levels ======"
input bool InpShowPivots = true;
input bool InpShowCamarilla = true;
input bool InpShowPDHPDL = true;
input int InpAsianStart = 0, InpAsianEnd = 8;
input int InpLondonStart = 8, InpLondonEnd = 16;
input int InpNewYorkStart = 13, InpNewYorkEnd = 21;
input group "====== Premium / Discount & OTE ======"
input bool InpShowPremiumDiscount = true;
input bool InpShowFibonacci = false;
input bool InpShowOTE = true;
input int InpSwingLookback = 120;
input int InpSwingRangeFractalN = 8;
input double InpOTEFibStart = 0.618;
input double InpOTEFibEnd = 0.79;
input int InpRangeBoxMaxBars = 60;
input group "====== v5.0 Algorithm Settings ======"
input bool InpUseBinarySearch = true;
input bool InpUseDynamicProg = true;
input bool InpUseKnapsack = true;
input bool InpUseBitMasking = true;
input bool InpUseMemoization = true;
input bool InpUseGraphTheory = true;
input group "====== QUALITY ENGINE - FLEXIBLE ======"
input bool InpRelaxedMode = true;
input bool InpRequireOB = false;
input bool InpRequireHTFBias = false;
input int InpMinSignalFactors = 2;
input bool InpAllowPartialFVG = true;
input bool InpShowQualityPanel = true;
input bool InpShowScoreBreakdown = true;
input int InpMinProbability = 50; // legacy preset name: minimum heuristic evidence score, NOT probability
input ENUM_MIN_GRADE InpMinGrade = GRADE_C;
input bool InpBlockLowGrade = false;
input int InpMinEntryOBStrength = 3;
input double InpMaxOBDistATR = 8.0;
input bool InpAlertOnSetup = true;
input int InpMinConfidenceScore = 45;
input group "====== Panel Layout ======"
input bool InpASCIIBar = true;
input int InpPanelRightPad = 68;
input int InpPanelFontSize = 0;
input bool InpPanelAutoWidth = true;
input int InpPanelMaxReasons = 8;
input bool InpShowDebugCounts = true;
input group "====== Clarity (1920x1080) ======"
input bool InpDeclutter = true;
input int InpPDTransparency = 97;
input group "====== AI Dashboard ======"
input bool InpShowAIDashboard = true;
input bool InpShowMTFPanel = true;
input bool InpShowTradeBox = true;
input group "====== Trade Levels (Pro) ======"
input bool InpDrawTradeLevels = true;
input bool InpUseMeanThreshold = true;
input bool InpSLBeyondSweep = true;
input double InpSLBufferATR = 0.2;
input bool InpSmartTargets = true;
input group "====== ICT Depth & Filters ======"
input ENUM_TIMEFRAMES InpHTFBiasTF = PERIOD_H4;
input bool InpUseHTFBias = true;
input bool InpDetectJudas = true;
input int InpMaxSpreadPts = 60;
input bool InpIgnoreSpreadOffHours = false;
input bool InpIgnoreSpreadInBacktest = true;
input int InpMaxStructureAge = 40;
input double InpADXChopLevel = 18.0;
input double InpADXTrendLevel = 25.0;
input group "====== Multi-Timeframe ======"
input ENUM_TIMEFRAMES InpMTF1 = PERIOD_MN1;
input ENUM_TIMEFRAMES InpMTF2 = PERIOD_W1;
input ENUM_TIMEFRAMES InpMTF3 = PERIOD_D1;
input ENUM_TIMEFRAMES InpMTF4 = PERIOD_H4;
input ENUM_TIMEFRAMES InpMTF5 = PERIOD_H1;
input group "====== Zone Colors ======"
input color InpColorOB = clrFireBrick;
input color InpColorOB_Bear = clrCrimson;
input color InpColorFVG = clrMediumOrchid;
input color InpColorDemand = clrSeaGreen;
input color InpColorSupply = clrDodgerBlue;
input color InpColorBreaker = clrGold;
input color InpColorPremium = clrIndianRed;
input color InpColorDiscount = clrForestGreen;
input color InpColorEQ = clrSilver;
input color InpColorFib = clrDarkGray;
input color InpColorOTE = clrAqua;
input group "====== DEBUGGING ======"
input bool DebugMode = false;            // v5.7.0: print PASS/FAIL table for every gate + error diagnostics
input bool InpShowDebugAlerts = false;
input bool InpLogSignalDetails = true;
input group "====== REAL-TIME MODE ======"
input bool InpRealTimeZones = true;
input bool InpUpdateEveryTick = true;
input bool InpRealTimeFractal = true;
input bool InpShowEarlyZones = true;
input int InpEarlyZoneTransparency = 94;
input group "====== SPEED / LATENCY ======"
input int InpMinRightConfirmBars = 1; // extra CLOSED bars after the structure break; 0 = no extra delay
input bool InpShowLatencyInPanel = true;

input group "====== SETUP -> RETEST -> CONFIRMED (NEW v5.2.0) ======"
input bool InpUseRetestLifecycle = true;
input bool InpIntersectFVGZone = true;
input double InpInvalidateBufferATR = 0.3;
input bool InpAlertOnSetupReady = false;

input group "====== v5.4.0 Performance & Stability ======"
input bool   InpUseIncrementalDetection = true;
input int    InpMaxStructuresKeep      = 30;
input int    InpMaxLiquidityKeep       = 40;
input int    InpMaxFVGKeep             = 25;
input int    InpMaxZonesKeep           = 20;
input int    InpRetestTimeoutBars      = 25;
input double InpRetestMaxDistanceATR   = 2.5;
input bool   InpSmartObjectManagement  = true;
input bool   InpLogLifecycleTransitions = false;
input int    InpIncrementalTailBars     = 12;  // v5.4.1: how many recent bars the incremental path actually rescans

#define PFX "QSMC_"
#define SIGPFX "QSMCSIG_"   // v5.7.0: persistent confirmed-signal markers (never touched by per-bar cleanup)

//--- bit masking
#define BIT_MSS           (1<<0)
#define BIT_BOS           (1<<1)
#define BIT_CHOCH         (1<<2)
#define BIT_STRONG_OB     (1<<3)
#define BIT_LIQUIDITY     (1<<4)
#define BIT_FVG           (1<<5)
#define BIT_OTE           (1<<6)
#define BIT_HTF_BIAS      (1<<7)
#define BIT_KILLZONE      (1<<8)
#define BIT_DEMAND_ZONE   (1<<9)
#define BIT_JUDAS         (1<<10)
#define BIT_SUPPLY_ZONE   (1<<11)   // v5.7.0: SELL-side twin of BIT_DEMAND_ZONE (was missing -> SELL stricter than BUY)
#define MAX_GRAPH_LINKS   16

// Boolean-factor indexes mirror the bit positions above (without bitwise checks).
enum ENUM_SIGNAL_FLAG
{
   FLAG_MSS, FLAG_BOS, FLAG_CHOCH, FLAG_STRONG_OB,
   FLAG_LIQUIDITY, FLAG_FVG, FLAG_OTE, FLAG_HTF_BIAS,
   FLAG_KILLZONE, FLAG_DEMAND_ZONE, FLAG_JUDAS, FLAG_SUPPLY_ZONE,
   FLAG_COUNT
};

//====================================================================
// GLOBALS
//====================================================================
datetime g_last_bar_time = 0;
int h_ema_fast, h_ema_slow, h_atr, h_adx, h_rsi;
int h_ema_mtf[5];
int g_signal_mask = 0;
bool g_signal_flags[FLAG_COUNT]; // used only when InpUseBitMasking=false
string g_ob_search_path="not run"; // actual code path shown in DebugMode
bool g_data_ready=false; // fail closed on required data-copy failures
double g_atr = 0.0;
double g_adx = 0.0;
long g_spread = 0;
int g_htf_bias = 0;
int g_judas = 0, g_judas_bar = 0;
datetime g_htf_cache_time = 0;
datetime g_d1_cache_time = 0;
bool g_memo_hit = false;
datetime g_last_alert_bar = 0;
int g_dash_lines = 0;
int g_dash_width = 300;
int g_rates_total = 0;
bool g_is_backtest = false;
int g_signal_count = 0;
//--- perf & chronological helpers
double g_cum_pv=0.0, g_cum_v=0.0;
datetime g_vwap_anchor=0;
double g_d1_high=0, g_d1_low=0, g_d1_close=0;
double g_htf_eq=0;
//--- P1.7 static price buffers (reuse, resize only when needed)
double g_buf_o[], g_buf_h[], g_buf_l[], g_buf_c[];
datetime g_buf_t[];
long g_buf_tv[];
int g_last_rates_total=0;
bool g_needs_full_rebuild=false;
//--- P0.4 enhanced blacklist: store idea hash + zone center + tolerance
string g_blacklist_zone_type[]; // "BUY"/"SELL"
double g_blacklist_zone_center[];
//--- v5.7.0 persistent structure-scanner state (true incremental, causal)
double g_str_last_high=0.0, g_str_last_low=0.0;
int    g_str_high_origin=-1, g_str_low_origin=-1;
int    g_str_trend=0;
bool   g_str_displacement=false;
int    g_str_scanned_to=-1;          // last CLOSED bar index already processed (-1 = never)
//--- v5.7.0 alert de-dup by signal identity (setup id + confirmed time + direction)
string g_last_alert_id="";
//--- v5.7.0 VWAP: cumulative sums cover CLOSED bars only; live bar is computed without mutating them
int    g_vwap_closed_to=-1;
bool   g_ema_filled=false;

//====================================================================
// STRUCTURES
//====================================================================
struct SStructureBreak
{
   int      bar;
   datetime time;
   double   price;
   bool     bullish;
   string   type;
   int      ob_bar;
   datetime confirmation_time; // close known at the next bar open
   datetime availability_time;
   int      swing_origin;
   int      swing_confirmation_bar;
   datetime swing_availability_time;
   double   displacement_atr; // measured current break, not a probability
   int      strength;
   int      priority;
};
struct SOrderBlock
{
   string   id; // STABLE UID
   int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   bool     mitigated;
   int      strength;
   string   state;
   double   distance_from_price;
   int      age;
};
struct SFVG
{
   int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   bool     filled;
   string   state;
   double   mid_price;
};
struct SLiquidity
{
   int      bar;
   datetime time;
   double   price;
   string   type;
   bool     swept;
   int      priority;
};
struct SKillZone
{
   datetime start,end;
   double   high,low;
   string   name;
   color    col;
};
struct SZone
{
   int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   string   state;
   int      touches;
   double   strength_score;
};
struct SBreaker
{
   int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   string   state;
};
struct SSignalFactor
{
   string name;
   int    value;
   int    weight;
   bool   active;
};
struct STradeSetup
{
   bool   valid;
   bool   is_buy;
   double entry,sl,tp1,tp2,tp3;
   int    confidence;
   string reasons[14];
   int    reason_count;
   string blockers[10];
   int    blocker_count;
   int    knapsack_score;
   int    dp_optimal_score;
   int    weighted_score;
   int    evidence_score;
   string quality_grade;
   string institutional_grade;
   string risk_level;
   double risk_pips;
   double rr1,rr2,rr3;
   string tp1_type,tp2_type,tp3_type;
   int    max_factor_value;
   int    ob_index; // cached index for rendering (resolved via UID)
   string ob_uid;   // STABLE UID
   double ob_dist_atr;
};
struct SScoreBreakdown
{
   double structure;
   double liquidity;
   double orderblock;
   double fvg;
   double session;
   double htf;
   double algo;
   double final_score;
};
struct SActiveSetup
{
   bool     active;
   string   id; // STABLE SETUP ID
   string   state; // READY | RETEST | CONFIRMED | INVALID
   bool     is_buy;
   int      created_bar; // for reference only
   datetime created_time; // actual availability, not the historical structure origin
   datetime structure_time; // immutable idea identity (may predate creation)
   double   zone_top, zone_bottom;
   string   ob_uid; // STABLE
   int      ob_index_cache; // resolved each tick
   string   quality_grade;
   string   institutional_grade;
   int      confidence;
   int      evidence_score;
   double   entry,sl,tp1,tp2,tp3;
   string   tp1_type,tp2_type,tp3_type;
   double   rr1,rr2,rr3;
   string   risk_level;
   double   risk_pips;
   int      confirmed_bar;
   datetime confirmed_time;
   bool     alert_fired;
};
struct SDealingRange
{
   bool     valid;
   int      bar_high,bar_low;
   datetime time_high,time_low;
   double   high,low,eq;
   bool     bullish_leg;
};
struct SGraphNode
{
   string type;
   double price;
   int    strength;
   int    links[MAX_GRAPH_LINKS];
   int    link_count;
   bool   visited;
};
struct STarget
{
   double price;
   int    priority;
   string type;
};

//====================================================================
// COLLECTIONS (chronological masters + index tables)
//====================================================================
SStructureBreak g_structures[];
SOrderBlock     g_order_blocks[];
SFVG            g_fvgs[];
SLiquidity      g_liquidity[];
SKillZone       g_kill_zones[];
SZone           g_zones[];
SBreaker        g_breakers[];
SGraphNode      g_market_graph[];
STradeSetup     g_trade_setup;
SActiveSetup    g_active_setup;
SDealingRange   g_range;
SScoreBreakdown g_score;
int g_ob_price_idx[];
int g_ob_strength_idx[];
int g_liq_priority_idx[];
//--- blacklist for terminal setups
string g_setup_blacklist[];
datetime g_blacklist_time[];

//====================================================================
// FORWARD DECLARATIONS
// v5.4.1 AUDIT FIX: every array parameter below now correctly reads
// "const TYPE &[]" instead of "const TYPE &". In MQL5 those are two
// different parameter kinds (single-value reference vs array
// reference); the previous declarations did not match their real
// definitions later in the file and would not compile. Struct-by-
// reference parameters (SFVG&, and true scalar out-params like
// double &risk_pips_out / string &type_out) are correctly left
// without [] since they really are single-value references.
//====================================================================
void DetectStructure(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[],const int scan_from=-1);
void DetectOrderBlocks(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[]);
void DetectZones(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[],const int scan_from=-1);
void DetectFVG(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[],const int scan_from=-1);
void DetectLiquidity(const int,const double&[],const double&[],const double&[],const double&[],const long&[],const datetime&[],const int scan_from=-1);
void DetectDealingRange(const int,const double&[],const double&[],const datetime&[]);
void ComputeHTFBias();
void DetectJudasSwing(const int,const datetime&[],const double&[],const double&[],const double&[]);
void DetectKillZones(const int,const datetime&[],const double&[],const double&[]);
bool GetOTEZone(double&,double&,bool&);
void AddBreakerBlock(const double&[],const double&[],const double&[],const datetime&[],const int,const double,const double,const bool,const int);
bool IsFractalHigh(const double&[],const int,const int,const int);
bool IsFractalLow(const double&[],const int,const int,const int);
int FindLastBearishOB(const double&[],const double&[],const int,const int);
int FindLastBullishOB(const double&[],const double&[],const int,const int);
void AddOrMergeFVG(SFVG&, const int, const double&[], const double&[]);
void DrawZoneBox(const string,const datetime,const double,const datetime,const double,const color,const string,const int);
void DrawTextLabel(const string,const datetime,const double,const string,const color,const bool,const int);
void DrawHLine(const string,const double,const color,const string,const int);
void DrawFibLine(const string,const datetime,const datetime,const double,const color,const int,const int);
void DrawLevelText(const string,const datetime,const double,const string,const color);
color BlendColor(const color,const int);
color GradeColor(const string);
color PctColor(const int);
string NormText(const string);
string TFName(const ENUM_TIMEFRAMES);
string IntegerToBinary(const int);
string L_Trim(const string);
double SafeVal(const double&[]);
datetime DayAnchor(const datetime);
double OBMid(const int);
double PipSize();
void RepositionDashboard();
void CalculateAITradeSetup(const int,const double&[],const double&[],const double&[],const double&[]);
void UpdateSignalMask(const int,const double&[]);
bool IsLatestStructureConfirmed(const int);
void MarkSignalFactor(const int,const int);
int BinarySearchNearestOB(const double,int&);
void BuildOBPriceIndex();
void BuildOBStrengthIndex();
void BuildLiquidityPriorityIndex();
void BuildMarketGraph();
int KnapsackOptimizeSignals(SSignalFactor&[],const int);
int DynamicProgrammingConfidence(SSignalFactor&[]);
double ScoreStructure(const int,const bool);
double ScoreLiquidity(const bool);
double ScoreOrderBlock(const int,const double,const double);
double ScoreFVG(const bool,const double);
double ScoreSession();
double ScoreHTF(const bool);
double ScoreAlgo(const int,const int,const int,const double);
int MaxPossibleValue(SSignalFactor&[]);
int CalculateEvidenceScore(const int,const int,const int,const int);
string CalculateQualityGrade(const int,const int);
int GradeRank(const string);
string GetInstitutionalGrade(const int,const int,const int,const int);
string CalculateRiskLevel(const double,const double,const double,const long,double&);
string BuildConfidenceBar(const int,const int);
int SelectEntryOB(const double,const bool,const double);
void AddReason(const string);
void AddBlocker(const string);
void FireSetupAlert(const datetime);
void ManageSetupLifecycle(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[],const bool);
void FillEMAAndVWAP(const int,const double&[],const double&[],const double&[],const double&[],const datetime&[],const long&[],const bool);
void DrawQuantumDashboard(const int,const double&[]);
void DrawMTFPanel();
void DrawTradeBox();
void DrawTradeLevels(const int,const datetime&[]);
void DrawPDHPDL();
void DrawPivotPoints();
void DrawCamarilla();
void DrawSessionHighLow(const int,const datetime&[],const double&[],const double&[]);
void DrawPremiumDiscount(const int,const datetime&[]);
void DrawBreakerZones();
void DrawStructureAndOB();
void DrawFVGZones();
void DrawLiquidityMarkers();
void DrawKillZones();
void DrawZones();
void DrawSetupZone(const int,const datetime&[]);
//--- new stable-id / blacklist / dedup helpers
string GenerateOBId(const datetime,const double,const double,const bool);
string GenerateSetupId(const bool,const datetime,const double,const double);
int FindOBIndexByUID(const string);
bool IsBlacklisted(const string);
void BlacklistSetup(const string,const datetime);
bool IsDuplicateLiquidity(const double,const string,const double);
bool IsDuplicateOB(const double,const double,const bool,const double);
double GreedyFindBestTarget(const double,const bool,const double,string&);
void PushTarget(STarget&[],STarget&);
double GraphConfluenceScore(const double);
//--- v5.4.0 P0/P1/P2 helpers
void EnforceArrayLimits();
void ReevaluateFVGState(SFVG &fvg, const int total, const double &h[], const double &l[]);
bool IsSameIdeaAsBlacklisted(const bool is_buy, const double zt, const double zb);
void SmartObjectCleanup(const bool isNewBar);
void LogLifecycle(const string msg);
bool SweepHasDisplacementOrVolume(const int sweep_bar, const bool is_high, const double level, const double atr, const double &h[], const double &l[], const double &o[], const double &c[], const long &tv[]);
//--- v5.7.0 helpers
void RefreshVolatilityAndSpread(const int total);
void UpdateLiquiditySweeps(const int total,const double &h[],const double &l[],const double &c[],const double &o[],const long &tv[],const datetime &t[]);
void UpdateBreakerStates(const int total,const double &h[],const double &l[],const double &c[]);
bool IsDuplicateBreaker(const int bar,const double top,const double bottom,const bool bullish);
void DebugPrint(const string msg);
void DebugError(const string func,const string what,const int err);
string PF(const bool ok);
void DrawPersistentSignal(const bool is_buy,const datetime tm,const double price,const string grade);

//====================================================================
// HELPERS - Stable IDs & Blacklist
//====================================================================
string GenerateOBId(const datetime t,const double top,const double bottom,const bool bullish)
{
   return StringFormat("OB_%s_%I64d_%.5f_%.5f_%s",_Symbol,(long)t,top,bottom,bullish?"B":"S");
}
string GenerateSetupId(const bool is_buy,const datetime ct,const double top,const double bottom)
{
   // P0.4 Enhanced: normalize to PipSize*0.5 to avoid floating noise, include symbol+TF+dir+time+zone
   double pip=PipSize();
   double nTop  = (pip>0? MathRound(top/pip)*pip : top);
   double nBottom = (pip>0? MathRound(bottom/pip)*pip : bottom);
   // also include ATR bucket to differentiate ideas on same zone but different volatility regime (optional)
   return StringFormat("SETUP_%s_%s_%s_%I64d_%.5f_%.5f",_Symbol,TFName((ENUM_TIMEFRAMES)_Period),is_buy?"BUY":"SELL",(long)ct,nTop,nBottom);
}
int FindOBIndexByUID(const string uid)
{
   if(uid=="") return -1;
   int n=ArraySize(g_order_blocks);
   for(int i=0;i<n;i++) if(g_order_blocks[i].id==uid) return i;
   return -1;
}
bool IsBlacklisted(const string id)
{
   int n=ArraySize(g_setup_blacklist);
   for(int i=0;i<n;i++) if(g_setup_blacklist[i]==id) return true;
   return false;
}
void BlacklistSetup(const string id,const datetime t)
{
   if(id=="" || IsBlacklisted(id)) return;
   int n=ArraySize(g_setup_blacklist);
   ArrayResize(g_setup_blacklist,n+1,32);
   ArrayResize(g_blacklist_time,n+1,32);
   ArrayResize(g_blacklist_zone_center,n+1,32);
   ArrayResize(g_blacklist_zone_type,n+1,32);
   g_setup_blacklist[n]=id;
   g_blacklist_time[n]=t;
   // P0.4 store center/dir for fuzzy same-idea check
   string dir="BUY";
   if(StringFind(id,"_SELL_")>=0) dir="SELL";
   else if(StringFind(id,"_BUY_")>=0) dir="BUY";
   g_blacklist_zone_type[n]=dir;
   double center=0;
   // parse last two prices from id tail: ..._top_bottom
   string parts[]; int cnt=StringSplit(id, (ushort)'_', parts);
   if(cnt>=2)
   {
      double top=StringToDouble(parts[cnt-2]);
      double bot=StringToDouble(parts[cnt-1]);
      if(top>0 && bot>0) center=(top+bot)*0.5;
   }
   g_blacklist_zone_center[n]=center;
   // prune old (>64 keep 32)
   if(n+1>64)
   {
      int keep=32;
      int newSize=n+1-keep;
      string tmp[]; datetime tmpt[]; string tmpT[]; double tmpC[];
      ArrayResize(tmp,newSize,32); ArrayResize(tmpt,newSize,32); ArrayResize(tmpT,newSize,32); ArrayResize(tmpC,newSize,32);
      for(int i=0;i<newSize;i++){ tmp[i]=g_setup_blacklist[i+keep]; tmpt[i]=g_blacklist_time[i+keep]; tmpT[i]=g_blacklist_zone_type[i+keep]; tmpC[i]=g_blacklist_zone_center[i+keep];}
      ArrayResize(g_setup_blacklist,newSize,32); ArrayResize(g_blacklist_time,newSize,32);
      ArrayResize(g_blacklist_zone_type,newSize,32); ArrayResize(g_blacklist_zone_center,newSize,32);
      for(int i=0;i<newSize;i++){ g_setup_blacklist[i]=tmp[i]; g_blacklist_time[i]=tmpt[i]; g_blacklist_zone_type[i]=tmpT[i]; g_blacklist_zone_center[i]=tmpC[i];}
   }
}
bool IsDuplicateLiquidity(const double price,const string type,const double tol)
{
   int n=ArraySize(g_liquidity);
   for(int i=0;i<n;i++)
   {
      if(g_liquidity[i].type!=type) continue;
      if(MathAbs(g_liquidity[i].price-price)<=tol) return true;
   }
   return false;
}
bool IsDuplicateOB(const double top,const double bottom,const bool bullish,const double tol)
{
   int n=ArraySize(g_order_blocks);
   for(int i=0;i<n;i++)
   {
      if(g_order_blocks[i].bullish!=bullish) continue;
      if(MathAbs(g_order_blocks[i].top-top)<=tol && MathAbs(g_order_blocks[i].bottom-bottom)<=tol) return true;
   }
   return false;
}
//--- v5.4.0 helpers
void LogLifecycle(const string msg)
{
   if(!InpLogLifecycleTransitions) return;
   Print("[Lifecycle] ",msg);
}
bool IsSameIdeaAsBlacklisted(const bool is_buy, const double zt, const double zb)
{
   // P0.4 fuzzy check: same direction + zone center within ATR*0.3 ~ same idea
   int n=ArraySize(g_setup_blacklist);
   if(n==0) return false;
   double center=(zt+zb)*0.5;
   double tol=(g_atr>0? g_atr*0.30 : 8*PipSize());
   string dir=is_buy?"BUY":"SELL";
   // v5.7.0 (R9): fuzzy entries expire. Without an expiry the blacklist
   // accumulated price-centred zones and blocked every later idea in the
   // same direction near price, permanently locking the engine.
   datetime now_t = (g_rates_total>0 && ArraySize(g_buf_t)>=g_rates_total) ? g_buf_t[g_rates_total-1] : TimeCurrent();
   long horizon = (long)MathMax(1,InpRetestTimeoutBars)*2*(long)PeriodSeconds();
   for(int i=0;i<n;i++)
   {
      if(i<ArraySize(g_blacklist_time) && g_blacklist_time[i]>0 && (long)(now_t-g_blacklist_time[i])>horizon) continue;
      // quick direction filter via substring
      if(StringFind(g_setup_blacklist[i],dir)<0) continue;
      // compare stored center if available
      if(i<ArraySize(g_blacklist_zone_center))
      {
         if(MathAbs(g_blacklist_zone_center[i]-center)<=tol && g_blacklist_zone_type[i]==dir)
            return true;
      }
      // fallback: try parse center from id? exact match already handled by IsBlacklisted
   }
   return false;
}
void EnforceArrayLimits()
{
   // P1.8 strict caps - delete oldest (chronological 0)
   if(InpMaxStructuresKeep>0 && ArraySize(g_structures)>InpMaxStructuresKeep)
   {
      int excess=ArraySize(g_structures)-InpMaxStructuresKeep;
      for(int i=0;i<ArraySize(g_structures)-excess;i++) g_structures[i]=g_structures[i+excess];
      ArrayResize(g_structures, InpMaxStructuresKeep, 32);
   }
   if(InpMaxLiquidityKeep>0 && ArraySize(g_liquidity)>InpMaxLiquidityKeep)
   {
      int excess=ArraySize(g_liquidity)-InpMaxLiquidityKeep;
      for(int i=0;i<ArraySize(g_liquidity)-excess;i++) g_liquidity[i]=g_liquidity[i+excess];
      ArrayResize(g_liquidity, InpMaxLiquidityKeep, 32);
      BuildLiquidityPriorityIndex();
   }
   if(InpMaxFVGKeep>0 && ArraySize(g_fvgs)>InpMaxFVGKeep)
   {
      int excess=ArraySize(g_fvgs)-InpMaxFVGKeep;
      for(int i=0;i<ArraySize(g_fvgs)-excess;i++) g_fvgs[i]=g_fvgs[i+excess];
      ArrayResize(g_fvgs, InpMaxFVGKeep, 32);
   }
   if(InpMaxZonesKeep>0 && ArraySize(g_zones)>InpMaxZonesKeep)
   {
      int excess=ArraySize(g_zones)-InpMaxZonesKeep;
      for(int i=0;i<ArraySize(g_zones)-excess;i++) g_zones[i]=g_zones[i+excess];
      ArrayResize(g_zones, InpMaxZonesKeep, 32);
   }
   // OrderBlocks capped via InpMaxStrongOB*2 already, but also enforce absolute
   int obHardCap = MathMax(InpMaxStrongOB*4, 12);
   if(ArraySize(g_order_blocks)>obHardCap)
   {
      BuildOBStrengthIndex();
      // keep strongest obHardCap
      SOrderBlock tmp[]; ArrayResize(tmp, obHardCap, 32);
      for(int i=0;i<obHardCap;i++) tmp[i]=g_order_blocks[g_ob_strength_idx[i]];
      // restore chrono order
      for(int i=1;i<obHardCap;i++){ SOrderBlock key=tmp[i]; int j=i-1; while(j>=0 && tmp[j].bar>key.bar){tmp[j+1]=tmp[j]; j--;} tmp[j+1]=key; }
      ArrayResize(g_order_blocks, obHardCap, 32);
      for(int i=0;i<obHardCap;i++) g_order_blocks[i]=tmp[i];
      BuildOBPriceIndex(); BuildOBStrengthIndex();
   }
}
void ReevaluateFVGState(SFVG &fvg, const int total, const double &h[], const double &l[])
{
   // P0.3: called after any merge or on incremental mitigation update
   if(total<3) return;
   int lastClosed=total-2;
   if(lastClosed<0 || lastClosed>=total) return;
   // reset then re-scan only closed bars after fvg.bar
   bool filled=false; string st="OPEN";
   for(int j=fvg.bar+1;j<=lastClosed;j++)
   {
      if(j<0 || j>=total) continue;
      if(fvg.bullish)
      {
         if(l[j]<=fvg.bottom){ filled=true; st="FILLED"; break; }
         else if(l[j]<fvg.top){ double fp=(fvg.top-l[j])/(fvg.top-fvg.bottom)*100; if(fp>50) st="PARTIAL"; }
      }
      else
      {
         if(h[j]>=fvg.top){ filled=true; st="FILLED"; break; }
         else if(h[j]>fvg.bottom){ double fp=(h[j]-fvg.bottom)/(fvg.top-fvg.bottom)*100; if(fp>50) st="PARTIAL"; }
      }
   }
   fvg.filled=filled;
   fvg.state=st;
   fvg.mid_price=(fvg.top+fvg.bottom)*0.5;
}
bool SweepHasDisplacementOrVolume(const int sweep_bar, const bool is_high, const double level, const double atr, const double &h[], const double &l[], const double &o[], const double &c[], const long &tv[])
{
   // P2.9: sweep must have displacement or relative volume
   if(sweep_bar<0 || sweep_bar>=ArraySize(h)) return false;
   double body=MathAbs(c[sweep_bar]-o[sweep_bar]);
   double range=h[sweep_bar]-l[sweep_bar];
   bool disp = (atr>0 && (body>=atr*0.40 || range>=atr*0.75));
   // volume filter: compare to avg of last 20
   if(!disp && ArraySize(tv)>20)
   {
      long sum=0; int cnt=0;
      for(int k=MathMax(0,sweep_bar-20);k<sweep_bar;k++){ sum+=(long)tv[k]; cnt++; }
      double avg=(cnt>0? (double)sum/cnt : 0);
      if(avg>0 && tv[sweep_bar]>=avg*1.6) disp=true;
   }
   // also require close beyond level (already checked) + wick beyond tolerance
   double beyond = is_high ? (h[sweep_bar]-level) : (level - l[sweep_bar]);
   if(beyond < (atr>0? atr*0.15 : 3*PipSize())) disp=false;
   return disp;
}
//====================================================================
// v5.7.0 HELPERS - debug, diagnostics, incremental maintenance
//====================================================================
void DebugPrint(const string msg){ if(DebugMode) Print(msg); }
string PF(const bool ok){ return ok ? "PASS" : "FAIL"; }
void DebugError(const string func,const string what,const int err)
{
   // Critical data failures are always reported (once per call site per bar is
   // naturally bounded because detection runs per bar, not per tick).
   Print(StringFormat("[ERROR] %s: %s | Symbol: %s | TF: %s | Error: %d",func,what,_Symbol,TFName((ENUM_TIMEFRAMES)_Period),err));
}
void RefreshVolatilityAndSpread(const int total)
{
   g_data_ready=true;
   g_atr=0; g_adx=0; // never retain previous-bar evidence on a failed read
   double tmp[]; ArraySetAsSeries(tmp,false);
   ResetLastError();
   if(CopyBuffer(h_atr,0,1,1,tmp)==1 && tmp[0]>0 && tmp[0]!=EMPTY_VALUE) g_atr=tmp[0];
   else { g_data_ready=false; DebugError("RefreshVolatilityAndSpread","ATR unavailable",GetLastError()); }
   if(CopyBuffer(h_adx,0,1,1,tmp)==1 && tmp[0]>=0 && tmp[0]!=EMPTY_VALUE) g_adx=tmp[0];
   else { g_data_ready=false; DebugError("RefreshVolatilityAndSpread","ADX unavailable",GetLastError()); }
   g_spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
}

bool IsDuplicateBreaker(const int bar,const double top,const double bottom,const bool bullish)
{
   for(int i=0;i<ArraySize(g_breakers);i++)
      if(g_breakers[i].bar==bar && g_breakers[i].bullish==bullish &&
         MathAbs(g_breakers[i].top-top)<_Point*2 && MathAbs(g_breakers[i].bottom-bottom)<_Point*2) return true;
   return false;
}
void UpdateBreakerStates(const int total,const double &h[],const double &l[],const double &c[])
{
   // incremental: touch / clear on the newly closed bar only
   if(total<3) return;
   int closed=total-2;
   for(int i=ArraySize(g_breakers)-1;i>=0;i--)
   {
      if(g_breakers[i].bar>=closed) continue;
      bool cleared=false;
      if(g_breakers[i].bullish){ if(l[closed]<=g_breakers[i].top && l[closed]>=g_breakers[i].bottom) g_breakers[i].state="TOUCHED"; if(c[closed]<g_breakers[i].bottom) cleared=true; }
      else                     { if(h[closed]>=g_breakers[i].bottom && h[closed]<=g_breakers[i].top) g_breakers[i].state="TOUCHED"; if(c[closed]>g_breakers[i].top) cleared=true; }
      if(cleared)
      {
         for(int k=i;k<ArraySize(g_breakers)-1;k++) g_breakers[k]=g_breakers[k+1];
         ArrayResize(g_breakers,ArraySize(g_breakers)-1,8);
      }
   }
}
void UpdateLiquiditySweeps(const int total,const double &h[],const double &l[],const double &c[],const double &o[],const long &tv[],const datetime &t[])
{
   // v5.7.0 (R5): in the incremental path the pool itself is usually older than the
   // tail window, so DetectLiquidity() hit IsDuplicateLiquidity() and `continue`d
   // BEFORE its sweep loop -> pools were never marked swept -> "Liquidity Taken"
   // could never activate live. This mirrors the original sweep rules (same
   // tolerance, 15-bar window, P2.9 displacement/volume filter) on the closed bar.
   if(total<3) return;
   int closed=total-2;
   double tol=(InpLiqToleranceATR>0 && g_atr>0)? g_atr*InpLiqToleranceATR : InpLiquidityTolerancePips*PipSize();
   if(tol<=0) tol=5*PipSize();
   int n=ArraySize(g_liquidity);
   for(int i=0;i<n;i++)
   {
      if(g_liquidity[i].swept) continue;
      bool is_high=false;
      if(g_liquidity[i].type=="EQH") is_high=true;
      else if(g_liquidity[i].type=="EQL") is_high=false;
      else continue;
      int pool_bar=g_liquidity[i].bar;
      if(closed<=pool_bar || closed>=pool_bar+15) continue;
      double level=g_liquidity[i].price;
      bool sweepHigh=( is_high && h[closed]>level+tol && c[closed]<level);
      bool sweepLow =(!is_high && l[closed]<level-tol && c[closed]>level);
      if(!sweepHigh && !sweepLow) continue;
      if(!SweepHasDisplacementOrVolume(closed,is_high,level,g_atr,h,l,o,c,tv)) continue;
      double sweptTol=tol*0.7;
      SLiquidity sw; sw.bar=closed; sw.time=t[closed]; sw.swept=true; sw.priority=0;
      if(sweepHigh){ if(IsDuplicateLiquidity(h[closed],"BSL TAKEN",sweptTol)) continue; sw.price=h[closed]; sw.type="BSL TAKEN"; }
      else         { if(IsDuplicateLiquidity(l[closed],"SSL TAKEN",sweptTol)) continue; sw.price=l[closed]; sw.type="SSL TAKEN"; }
      int idx=ArraySize(g_liquidity); ArrayResize(g_liquidity,idx+1,16); g_liquidity[idx]=sw;
      DebugPrint(StringFormat("[Liquidity] %s @ %s on closed bar %d",sw.type,DoubleToString(sw.price,_Digits),closed));
   }
}
void DrawPersistentSignal(const bool is_buy,const datetime tm,const double price,const string grade)
{
   // v5.7.0 (R11): one immutable arrow per confirmed signal. Name = direction + bar time,
   // so it is unique, is never re-created on a different bar, and survives per-bar cleanup.
   string name=SIGPFX+TFName((ENUM_TIMEFRAMES)_Period)+"_"+(is_buy?"BUY_":"SELL_")+IntegerToString((long)tm);
   if(ObjectFind(0,name)>=0) return;
   ResetLastError();
   if(!ObjectCreate(0,name,OBJ_ARROW,0,tm,price))
   { DebugError("DrawPersistentSignal","ObjectCreate failed for "+name,GetLastError()); return; }
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,is_buy?233:234);
   ObjectSetInteger(0,name,OBJPROP_COLOR,is_buy?clrLime:clrRed);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,is_buy?ANCHOR_TOP:ANCHOR_BOTTOM);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,StringFormat("%s %s CONFIRMED @ %s",grade,is_buy?"BUY":"SELL",DoubleToString(price,_Digits)));
}
void SmartObjectCleanup(const bool isNewBar)
{
   // P1.6: delete only dead objects, keep live ones
   if(!InpSmartObjectManagement) return;
   // Delete setup zone if no active setup
   if(!g_active_setup.active)
   {
      ObjectDelete(0, PFX+"SETUPZONE");
      ObjectDelete(0, PFX+"SETUPZONE_L");
   }
   // v5.7.0 (R8): when no valid trade, remove ALL trade visuals (lines, arrow,
   // connector, trade box). Previously ENTRY/SL/TP lines and the trade box were
   // never deleted, so retired levels stayed on the chart indefinitely.
   if(!g_trade_setup.valid)
   {
      ObjectDelete(0, PFX+"ENTRY_ARROW");
      ObjectDelete(0, PFX+"CONNECT");
      ObjectDelete(0, PFX+"ENTRY"); ObjectDelete(0, PFX+"SL");
      ObjectDelete(0, PFX+"TP1"); ObjectDelete(0, PFX+"TP2"); ObjectDelete(0, PFX+"TP3");
      ObjectDelete(0, PFX+"TRADE_BOX_BG");
      for(int i=0;i<10;i++) ObjectDelete(0, PFX+"TBOX_"+IntegerToString(i));
   }
   // v5.7.0 (R8): index-named objects (STR_i, OB_i_bar, FVGi, ZN_i, BRK_i, LIQ_i, KZ_i)
   // are re-drawn from the arrays once per bar. Arrays shift when caps are enforced,
   // so index i may point at a different element next bar; the old brute-force
   // "dead index" scan (and its wrong OB_i_i pattern) left stale labels behind.
   // Deleting by prefix once per bar is cheap and exact. Dashboard/panels/lines
   // with fixed names are untouched. SIGPFX markers are never touched here.
   if(isNewBar)
   {
      ObjectsDeleteAll(0, PFX+"STR_");
      ObjectsDeleteAll(0, PFX+"OB_");
      ObjectsDeleteAll(0, PFX+"FVG");
      ObjectsDeleteAll(0, PFX+"ZN_");
      ObjectsDeleteAll(0, PFX+"BRK_");
      ObjectsDeleteAll(0, PFX+"LIQ_");
      ObjectsDeleteAll(0, PFX+"KZ_");
      ObjectDelete(0, PFX+"JUDAS");
   }
}

//====================================================================
// INIT / DEINIT / EVENTS
//====================================================================
int OnInit()
{
   if(InpATRPeriod<1 || InpADXPeriod<1 || InpRSIPeriod<1 || InpEMAFast<1 || InpEMASlow<1 ||
      InpSwingFractalN<1 || InpLiquidityFractalN<1 || InpSwingRangeFractalN<1 ||
      InpSwingLookback<2 || InpOBLookback<1 || InpMaxStrongOB<1 || InpMaxZonesShown<1 ||
      InpIncrementalTailBars<InpLiquidityFractalN*2 || InpDisplacementATR<=0 ||
      InpZoneMaxHeightATR<=0 || InpOBMaxHeightATR<=0 || InpFVGMinSizeATR<=0 ||
      InpOTEFibStart<0 || InpOTEFibEnd>1 || InpOTEFibStart>=InpOTEFibEnd ||
      InpMinRightConfirmBars<0)
   {
      Print("Invalid periods, bounds, confirmation window or OTE inputs");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMergeFVG) Print("FVG evidence merging disabled: origin geometry must remain immutable");
   SetIndexBuffer(0, BufEmaFast, INDICATOR_DATA);
   SetIndexBuffer(1, BufEmaSlow, INDICATOR_DATA);
   SetIndexBuffer(2, BufVWAP, INDICATOR_DATA);
   // enforce chronological (0=oldest) for indicator buffers
   ArraySetAsSeries(BufEmaFast,false);
   ArraySetAsSeries(BufEmaSlow,false);
   ArraySetAsSeries(BufVWAP,false);
   // v5.7.0: do not draw EMA lines over the warm-up region (values were 0.0 there)
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetDouble(2,PLOT_EMPTY_VALUE,0.0);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpEMAFast);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpEMASlow);
   IndicatorSetString(INDICATOR_SHORTNAME,"Quantum SMC AI Pro v5.8.0");

   h_ema_fast = iMA(_Symbol, PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   h_ema_slow = iMA(_Symbol, PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   h_atr = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   h_adx = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   h_rsi = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   ENUM_TIMEFRAMES mtf_list[] = {InpMTF1, InpMTF2, InpMTF3, InpMTF4, InpMTF5};
   for(int i=0;i<5;i++)
      h_ema_mtf[i] = iMA(_Symbol, mtf_list[i], InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   if(h_ema_fast==INVALID_HANDLE || h_ema_slow==INVALID_HANDLE ||
      h_atr==INVALID_HANDLE || h_adx==INVALID_HANDLE || h_rsi==INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return INIT_FAILED;
   }
   for(int i=0;i<5;i++) if(h_ema_mtf[i]==INVALID_HANDLE) Print("MTF handle ",i," failed");

   ArrayResize(g_structures,0,32);
   ArrayResize(g_order_blocks,0,32);
   ArrayResize(g_fvgs,0,32);
   ArrayResize(g_liquidity,0,32);
   ArrayResize(g_kill_zones,0,8);
   ArrayResize(g_zones,0,32);
   ArrayResize(g_breakers,0,8);
   ArrayResize(g_market_graph,0,32);
   ArrayResize(g_ob_price_idx,0,32);
   ArrayResize(g_ob_strength_idx,0,32);
   ArrayResize(g_liq_priority_idx,0,32);
   ArrayResize(g_setup_blacklist,0,32);
   ArrayResize(g_blacklist_time,0,32);
   ArrayResize(g_blacklist_zone_center,0,32);
   ArrayResize(g_blacklist_zone_type,0,32);
   ArrayResize(g_buf_o,0,32); ArrayResize(g_buf_h,0,32); ArrayResize(g_buf_l,0,32); ArrayResize(g_buf_c,0,32);
   ArrayResize(g_buf_t,0,32); ArrayResize(g_buf_tv,0,32);
   g_last_rates_total=0; g_needs_full_rebuild=true;

   g_trade_setup.valid=false; g_trade_setup.ob_uid=""; g_trade_setup.ob_index=-1;
   g_active_setup.active=false; g_active_setup.state="NONE"; g_active_setup.id="";
   g_active_setup.created_bar=-1; g_active_setup.confirmed_bar=-1; g_active_setup.alert_fired=false;
   g_active_setup.ob_uid=""; g_active_setup.ob_index_cache=-1;
   g_range.valid=false;
   g_dash_lines=0;
   g_signal_count=0;
   g_is_backtest = (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_VISUAL_MODE));
   g_cum_pv=0; g_cum_v=0; g_vwap_anchor=0; g_vwap_closed_to=-1; g_ema_filled=false;
   g_d1_cache_time=0; g_htf_cache_time=0;
   g_str_last_high=0; g_str_last_low=0; g_str_trend=0; g_str_displacement=false; g_str_scanned_to=-1;
   g_last_alert_id=""; g_last_alert_bar=0; g_last_bar_time=0;
   g_signal_mask=0; g_ob_search_path="not run";
   for(int i=0;i<FLAG_COUNT;i++) g_signal_flags[i]=false;

   Print("======================================================");
   Print(" Quantum SMC AI v5.8.0 - P1 SIGNAL ENGINE INPUTS (DebugMode=",DebugMode?"ON":"OFF",")");
   Print("======================================================");
   Print(" Symbol: ",_Symbol," | Digits: ",(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
   Print(" Point: ",DoubleToString(_Point,5)," | PipSize: ",DoubleToString(PipSize(),5));
   Print(" Mode: ",g_is_backtest ? "BACKTEST" : "LIVE TRADING");
   Print("------------------------------------------------------");
   Print(" LATENCY SETTINGS:");
   Print(" - Swing Fractal N: ",InpSwingFractalN);
   Print(" - Liquidity Fractal N: ",InpLiquidityFractalN);
   Print(" - Displacement ATR: ",DoubleToString(InpDisplacementATR,2));
   Print(" - Min Right Confirm Bars: ",InpMinRightConfirmBars," additional CLOSED bars after break");
   Print(" - OB Search: ",InpUseBinarySearch?"BINARY INDEX":"LINEAR SCAN",
         " | Signal Factors: ",InpUseBitMasking?"BITMASK":"BOOL FLAGS");
   Print(" - RealTime Zones: ",InpRealTimeZones ? "ON (Tick)" : "OFF (Confirmed)");
   Print(" - Update Every Tick: ",InpUpdateEveryTick ? "YES" : "NO (Bar Close)");
   Print(" - Incremental: ", InpUseIncrementalDetection ? "ON" : "OFF"," (tail window: ",InpIncrementalTailBars," bars)");
   Print(" - Caps: Struct ",InpMaxStructuresKeep," Liq ",InpMaxLiquidityKeep," FVG ",InpMaxFVGKeep," Zones ",InpMaxZonesKeep);
   Print(" - RetestTimeout: ",InpRetestTimeoutBars," bars / ",DoubleToString(InpRetestMaxDistanceATR,1)," ATR");
   Print("======================================================");
   if(InpRealTimeZones)
      Print(">>> REALTIME MODE ACTIVE: zones/signals on closed bars only; RETEST requires a subsequent closed bar.");
   Print(">>> v5.8.0: engine/lifecycle use closed bars; P1 right-confirm gate applies before setup scoring.");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   IndicatorRelease(h_ema_fast); IndicatorRelease(h_ema_slow);
   IndicatorRelease(h_atr); IndicatorRelease(h_adx); IndicatorRelease(h_rsi);
   for(int i=0;i<5;i++) IndicatorRelease(h_ema_mtf[i]);
   // Remove everything we own when the indicator is removed / re-initialised.
   // (On a timeframe/parameter change the next OnCalculate does a full rebuild
   //  and re-creates the chart state deterministically from closed bars.)
   ObjectsDeleteAll(0,PFX);
   // A new configuration requires new signal evidence; remove old markers.
   ObjectsDeleteAll(0,SIGPFX); // never retain unvalidated arrows across parameter/TF changes
   Print("=========================================");
   Print(" Quantum SMC v5.8.0 Stopped (reason ",reason,")");
   Print(" Total Signals Generated: ",g_signal_count);
   Print("=========================================");
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      if(InpShowAIDashboard) RepositionDashboard();
      ChartRedraw(0);
   }
   if(id==CHARTEVENT_CUSTOM)
   {
      ChartRedraw(0); // presentation event must not replay a closed-bar transition
   }
}
void RepositionDashboard()
{
   int chart_w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   if(chart_w<=0) return;
   int bg_x=chart_w - InpPanelRightPad - g_dash_width;
   if(bg_x<5) bg_x=5;
   int txt_x=bg_x+8;
   string bg=PFX+"DASH_BG";
   if(ObjectFind(0,bg)>=0) ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,bg_x);
   for(int i=0;i<g_dash_lines;i++)
   {
      string name=PFX+"DASH_"+IntegerToString(i);
      if(ObjectFind(0,name)>=0) ObjectSetInteger(0,name,OBJPROP_XDISTANCE,txt_x);
   }
}

//====================================================================
// MAIN - OnCalculate
// v5.7.0 execution model (R1):
//   FULL REBUILD : first load / history reload / TF change / caps disabled
//   NEW BAR      : incremental detection on the newly CLOSED bar (total-2),
//                  then the decision engine (CalculateAITradeSetup) runs ONCE.
//   TICK         : NO detection/decision/lifecycle transition; dashboards only.
// Intended closed-bar schedule only. Whole-engine replay equivalence is NOT
// established; see VALIDATION_REPORT.md for subsystem-level test coverage.
//====================================================================
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   // P0.1 Guard: need at least 3 bars for total-2 logic
   if(rates_total < 3) return 0;
   if(rates_total < InpEMASlow+50) return 0;

   //--- chronological check: ensure index 0 = oldest, rates_total-1 = live
   bool is_series = ArrayGetAsSeries(time);
   datetime cur = is_series ? time[0] : time[rates_total-1];

   bool first_run  = (prev_calculated==0);
   bool is_new_bar = (cur != g_last_bar_time);
   // respect InpUpdateEveryTick=false: skip pure tick updates
   if(!is_new_bar && !first_run && !InpUpdateEveryTick) return rates_total;
   if(is_new_bar) g_last_bar_time=cur;
   g_rates_total=rates_total;

   //--- decide execution mode ------------------------------------------------
   bool full_rebuild = first_run || g_needs_full_rebuild || !InpUseIncrementalDetection
                       || ArraySize(g_buf_o)!=g_last_rates_total;
   if(!full_rebuild)
   {
      // history must have grown by exactly one bar on a new bar, or not at all on a tick
      if(is_new_bar  && rates_total!=g_last_rates_total+1) full_rebuild=true;
      if(!is_new_bar && rates_total!=g_last_rates_total)   full_rebuild=true;
      // nothing tracked yet -> rebuild once per new bar until structure exists
      if(is_new_bar && ArraySize(g_structures)==0) full_rebuild=true;
   }
   // !InpUseIncrementalDetection => full rebuild once per NEW BAR (never per tick)
   if(!InpUseIncrementalDetection && !is_new_bar && !first_run && !g_needs_full_rebuild && ArraySize(g_buf_o)==rates_total)
      full_rebuild=false;

   //--- P1.7 static price buffers: resize only when needed --------------------
   if(ArraySize(g_buf_o)!=rates_total)
   {
      ArrayResize(g_buf_o, rates_total, 64);
      ArrayResize(g_buf_h, rates_total, 64);
      ArrayResize(g_buf_l, rates_total, 64);
      ArrayResize(g_buf_c, rates_total, 64);
      ArrayResize(g_buf_t, rates_total, 64);
      ArrayResize(g_buf_tv, rates_total, 64);
   }
   // copy chronologically: everything on rebuild, last 3 bars on a new bar, last 2 on a tick
   int copy_from = full_rebuild ? 0 : (is_new_bar ? MathMax(0,rates_total-3) : MathMax(0,rates_total-2));
   for(int k=copy_from;k<rates_total;k++)
   {
      int src = is_series ? (rates_total-1-k) : k;
      g_buf_o[k]=open[ArrayGetAsSeries(open)?rates_total-1-k:k];
      g_buf_h[k]=high[ArrayGetAsSeries(high)?rates_total-1-k:k];
      g_buf_l[k]=low[ArrayGetAsSeries(low)?rates_total-1-k:k];
      g_buf_c[k]=close[ArrayGetAsSeries(close)?rates_total-1-k:k];
      g_buf_t[k]=time[src];
      g_buf_tv[k]=tick_volume[ArrayGetAsSeries(tick_volume)?rates_total-1-k:k];
   }

   //--- EMA / VWAP (incremental; closed-bar cumulative VWAP)
   if(full_rebuild){ g_ema_filled=false; g_vwap_closed_to=-1; g_vwap_anchor=0; }
   FillEMAAndVWAP(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t,g_buf_tv,is_new_bar || full_rebuild);

   //--- redraw mode & object management
   bool needs_full_redraw = is_new_bar || full_rebuild;
   if(InpSmartObjectManagement)
      SmartObjectCleanup(needs_full_redraw);
   else if(needs_full_redraw)
      ObjectsDeleteAll(0,PFX);

   bool run_engine=false;
   int closed = rates_total-2;

   if(full_rebuild)
   {
      //================= FULL REBUILD (first run / history change) ===========
      ArrayResize(g_structures,0,32);
      ArrayResize(g_order_blocks,0,32);
      ArrayResize(g_fvgs,0,32);
      ArrayResize(g_liquidity,0,32);
      ArrayResize(g_kill_zones,0,8);
      ArrayResize(g_zones,0,32);
      ArrayResize(g_breakers,0,8);
      ArrayResize(g_market_graph,0,32);
      ArrayResize(g_ob_price_idx,0,32);
      ArrayResize(g_ob_strength_idx,0,32);
      ArrayResize(g_liq_priority_idx,0,32);
      g_signal_mask=0;
      for(int i=0;i<FLAG_COUNT;i++) g_signal_flags[i]=false;
      g_htf_cache_time=0; g_d1_cache_time=0;
      g_str_scanned_to=-1;   // reset causal structure scanner

      RefreshVolatilityAndSpread(rates_total);

      DetectStructure(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t);
      DetectOrderBlocks(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t);
      BuildOBPriceIndex();
      BuildOBStrengthIndex();
      DetectZones(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t);
      DetectFVG(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t);
      DetectLiquidity(rates_total,g_buf_h,g_buf_l,g_buf_c,g_buf_o,g_buf_tv,g_buf_t);
      BuildLiquidityPriorityIndex();
      DetectDealingRange(rates_total,g_buf_h,g_buf_l,g_buf_t);
      ComputeHTFBias();
      if(InpDetectJudas) DetectJudasSwing(rates_total,g_buf_t,g_buf_h,g_buf_l,g_buf_c);
      if(InpShowKillZones) DetectKillZones(rates_total,g_buf_t,g_buf_h,g_buf_l);
      g_needs_full_rebuild=false;
      run_engine=true;
      DebugPrint(StringFormat("[Engine] FULL REBUILD bars=%d struct=%d OB=%d FVG=%d LQ=%d ZN=%d",rates_total,ArraySize(g_structures),ArraySize(g_order_blocks),ArraySize(g_fvgs),ArraySize(g_liquidity),ArraySize(g_zones)));
   }
   else if(is_new_bar)
   {
      //================= NEW BAR: incremental update on the closed bar =======
      RefreshVolatilityAndSpread(rates_total);

      // P0.3 & mitigation incremental updates (closed bar only)
      for(int i=0;i<ArraySize(g_fvgs);i++) ReevaluateFVGState(g_fvgs[i], rates_total, g_buf_h, g_buf_l);
      for(int i=0;i<ArraySize(g_order_blocks);i++)
      {
         if(g_order_blocks[i].state=="MITIGATED") continue;
         bool bull=g_order_blocks[i].bullish;
         if(bull && g_buf_l[closed]<=g_order_blocks[i].top && g_buf_l[closed]>=g_order_blocks[i].bottom) g_order_blocks[i].state="TOUCHED";
         if(!bull && g_buf_h[closed]>=g_order_blocks[i].bottom && g_buf_h[closed]<=g_order_blocks[i].top) g_order_blocks[i].state="TOUCHED";
         if(bull && g_buf_c[closed]<g_order_blocks[i].bottom){ g_order_blocks[i].mitigated=true; g_order_blocks[i].state="MITIGATED"; }
         if(!bull && g_buf_c[closed]>g_order_blocks[i].top){ g_order_blocks[i].mitigated=true; g_order_blocks[i].state="MITIGATED"; }
      }
      for(int i=0;i<ArraySize(g_zones);i++)
      {
         if(g_zones[i].state=="MITIGATED") continue;
         if(g_zones[i].bullish)
         {
            if(g_buf_l[closed]<=g_zones[i].top && g_buf_l[closed]>=g_zones[i].bottom){ g_zones[i].touches++; g_zones[i].state="MITIGATION"; }
            if(g_buf_c[closed]<g_zones[i].bottom) g_zones[i].state="MITIGATED";
         }
         else
         {
            if(g_buf_h[closed]>=g_zones[i].bottom && g_buf_h[closed]<=g_zones[i].top){ g_zones[i].touches++; g_zones[i].state="MITIGATION"; }
            if(g_buf_c[closed]>g_zones[i].top) g_zones[i].state="MITIGATED";
         }
      }
      UpdateBreakerStates(rates_total,g_buf_h,g_buf_l,g_buf_c);
      UpdateLiquiditySweeps(rates_total,g_buf_h,g_buf_l,g_buf_c,g_buf_o,g_buf_tv,g_buf_t);

      // Structure continues from its persistent causal state (exactly the bars
      // not yet processed); local-pattern detectors rescan a short tail (dedup-guarded).
      int tail_from = MathMax(0, closed - InpIncrementalTailBars);
      DetectStructure(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t,tail_from);
      DetectOrderBlocks(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t);
      DetectFVG(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t,tail_from);
      DetectLiquidity(rates_total,g_buf_h,g_buf_l,g_buf_c,g_buf_o,g_buf_tv,g_buf_t,tail_from);
      DetectZones(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t,tail_from);
      // context that the old incremental branch never refreshed (R5)
      DetectDealingRange(rates_total,g_buf_h,g_buf_l,g_buf_t);
      ComputeHTFBias();
      if(InpDetectJudas) DetectJudasSwing(rates_total,g_buf_t,g_buf_h,g_buf_l,g_buf_c);
      if(InpShowKillZones){ ArrayResize(g_kill_zones,0,8); DetectKillZones(rates_total,g_buf_t,g_buf_h,g_buf_l); }
      run_engine=true;
      LogLifecycle(StringFormat("Incremental update: new closed=%d struct=%d OB=%d FVG=%d LQ=%d",closed,ArraySize(g_structures),ArraySize(g_order_blocks),ArraySize(g_fvgs),ArraySize(g_liquidity)));
   }
   else
   {
      //================= TICK: light refresh only ===========================
      g_spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   }
   g_last_rates_total=rates_total;

   // Data failures must not score stale collections or confirm a tracked setup.
   // Next callback requests a rebuild; no prediction/alert is issued on this pass.
   if(run_engine && !g_data_ready)
   {
      g_needs_full_rebuild=true;
      g_trade_setup.valid=false;
      SmartObjectCleanup(false);
      return 0;
   }

   //--- DECISION ENGINE: once per closed bar ----------------------------------
   if(run_engine)
   {
      EnforceArrayLimits();
      BuildOBPriceIndex(); BuildOBStrengthIndex(); BuildLiquidityPriorityIndex();
      UpdateSignalMask(rates_total,g_buf_c);
      if(InpUseGraphTheory) BuildMarketGraph();
      CalculateAITradeSetup(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c);
   }

   // Call for presentation continuity; transitions are closed-bar only.
   ManageSetupLifecycle(rates_total,g_buf_o,g_buf_h,g_buf_l,g_buf_c,g_buf_t,is_new_bar || full_rebuild);
   SmartObjectCleanup(false); // remove visuals retired by this transition

   //--- DRAWING: full vs delta
   if(needs_full_redraw)
   {
      if(InpShowPremiumDiscount || InpShowFibonacci || InpShowOTE)
         DrawPremiumDiscount(rates_total,g_buf_t);
      DrawZones();
      DrawStructureAndOB();
      if(InpShowBreakers) DrawBreakerZones();
      DrawFVGZones();
      DrawLiquidityMarkers();
      if(InpShowKillZones) DrawKillZones();
      if(InpDetectJudas && g_judas!=0 && g_judas_bar>=0 && g_judas_bar<rates_total)
         DrawTextLabel(PFX+"JUDAS",g_buf_t[g_judas_bar],
                       g_judas==1 ? g_buf_l[g_judas_bar] : g_buf_h[g_judas_bar],
                       g_judas==1 ? "JUDAS UP" : "JUDAS DN",
                       g_judas==1 ? clrLime : clrRed,g_judas!=1,9);
      if(InpShowPDHPDL) DrawPDHPDL();
      if(InpShowPivots) DrawPivotPoints();
      if(InpShowCamarilla) DrawCamarilla();
      if(InpShowSessionHL) DrawSessionHighLow(rates_total,g_buf_t,g_buf_h,g_buf_l);
   }

   // dashboard & trade visuals update every tick (delta)
   if(InpShowAIDashboard) DrawQuantumDashboard(rates_total,g_buf_c);
   if(InpShowMTFPanel) DrawMTFPanel();
   // setup zone: create on full, extend on tick
   if(InpUseRetestLifecycle && g_active_setup.active && (g_active_setup.state=="READY" || g_active_setup.state=="RETEST"))
   {
      if(needs_full_redraw || ObjectFind(0,PFX+"SETUPZONE")<0) DrawSetupZone(rates_total,g_buf_t);
      else
      {
         string name=PFX+"SETUPZONE";
         datetime t2 = g_buf_t[rates_total-1] + (datetime)(PeriodSeconds()*15);
         ObjectMove(0,name,1,t2,g_active_setup.zone_bottom);
      }
   }
   if(InpShowTradeBox && g_trade_setup.valid) DrawTradeBox();
   if(InpDrawTradeLevels && g_trade_setup.valid) DrawTradeLevels(rates_total,g_buf_t);
   FireSetupAlert(cur);

   return rates_total;
}


//====================================================================
// SYMBOL-AWARE PIP SIZE
//====================================================================
double PipSize()
{
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pt=_Point;
   if(d==5 || d==3) return pt*10.0;
   if(d==2) return pt*10.0;
   if(d==1) return pt*10.0;
   return pt;
}

//====================================================================
// ALGORITHMS
//====================================================================
double OBMid(const int i)
{
   if(i<0 || i>=ArraySize(g_order_blocks)) return 0;
   return (g_order_blocks[i].top + g_order_blocks[i].bottom)*0.5;
}
void BuildOBPriceIndex()
{
   int n=ArraySize(g_order_blocks);
   ArrayResize(g_ob_price_idx,n,32);
   for(int i=0;i<n;i++) g_ob_price_idx[i]=i;
   for(int i=1;i<n;i++)
   {
      int key=g_ob_price_idx[i];
      double kp=OBMid(key);
      int j=i-1;
      while(j>=0 && OBMid(g_ob_price_idx[j])>kp)
      { g_ob_price_idx[j+1]=g_ob_price_idx[j]; j--; }
      g_ob_price_idx[j+1]=key;
   }
}
void BuildOBStrengthIndex()
{
   int n=ArraySize(g_order_blocks);
   ArrayResize(g_ob_strength_idx,n,32);
   for(int i=0;i<n;i++) g_ob_strength_idx[i]=i;
   // insertion sort descending strength, stable - does not mutate master
   for(int i=1;i<n;i++)
   {
      int key=g_ob_strength_idx[i];
      int ks=g_order_blocks[key].strength;
      int j=i-1;
      while(j>=0 && g_order_blocks[g_ob_strength_idx[j]].strength < ks)
      { g_ob_strength_idx[j+1]=g_ob_strength_idx[j]; j--; }
      g_ob_strength_idx[j+1]=key;
   }
}
void BuildLiquidityPriorityIndex()
{
   int n=ArraySize(g_liquidity);
   ArrayResize(g_liq_priority_idx,n,32);
   for(int i=0;i<n;i++) g_liq_priority_idx[i]=i;
   // assign priorities
   for(int i=0;i<n;i++)
   {
      if(g_liquidity[i].swept) g_liquidity[i].priority=10;
      else if(g_liquidity[i].type=="EQH" || g_liquidity[i].type=="EQL") g_liquidity[i].priority=5;
      else g_liquidity[i].priority=1;
   }
   // sort index by priority descending
   for(int i=1;i<n;i++)
   {
      int key=g_liq_priority_idx[i];
      int kp=g_liquidity[key].priority;
      int j=i-1;
      while(j>=0 && g_liquidity[g_liq_priority_idx[j]].priority < kp)
      { g_liq_priority_idx[j+1]=g_liq_priority_idx[j]; j--; }
      g_liq_priority_idx[j+1]=key;
   }
}
int BinarySearchNearestOB(const double target_price,int &sorted_pos)
{
   // Return the master OB index AND its position in the sorted price index.
   // The caller must still rank every eligible block, not just this nearest one.
   int n=ArraySize(g_ob_price_idx);
   sorted_pos=-1;
   if(n==0) return -1;
   int lo=0,hi=n-1,best=g_ob_price_idx[0];
   double best_d=DBL_MAX;
   while(lo<=hi)
   {
      int mid=lo+(hi-lo)/2;
      int oi=g_ob_price_idx[mid];
      double mp=OBMid(oi);
      double d=MathAbs(target_price-mp);
      if(d<best_d){best_d=d; best=oi; sorted_pos=mid;}
      if(mp<target_price) lo=mid+1; else hi=mid-1;
   }
   return best;
}
bool IsLatestStructureConfirmed(const int closed_bar)
{
   int n=ArraySize(g_structures);
   if(n==0 || closed_bar<0) return false;
   int break_bar=g_structures[n-1].bar;
   return break_bar>=0 && break_bar<=closed_bar &&
          closed_bar-break_bar>=InpMinRightConfirmBars;
}
void MarkSignalFactor(const int flag,const int bit)
{
   if(InpUseBitMasking) g_signal_mask|=bit;
   else                 g_signal_flags[flag]=true;
}
void UpdateSignalMask(const int total,const double &c[])
{
   g_signal_mask=0;
   for(int i=0;i<FLAG_COUNT;i++) g_signal_flags[i]=false;
   if(total<3) return;
   // Both paths use the LAST CLOSED bar. A detected break remains pending
   // until InpMinRightConfirmBars more bars AFTER it have closed.
   double price=c[total-2];
   int ns=ArraySize(g_structures);
   if(IsLatestStructureConfirmed(total-2))
   {
      string ty=g_structures[ns-1].type;
      if(ty=="MSS")        MarkSignalFactor(FLAG_MSS,BIT_MSS);
      else if(ty=="BOS")   MarkSignalFactor(FLAG_BOS,BIT_BOS);
      else if(ty=="CHoCH") MarkSignalFactor(FLAG_CHOCH,BIT_CHOCH);
   }
   for(int i=0;i<ArraySize(g_order_blocks);i++)
      if(g_order_blocks[i].strength>=4 && g_order_blocks[i].state!="MITIGATED")
      {MarkSignalFactor(FLAG_STRONG_OB,BIT_STRONG_OB); break;}
   for(int i=ArraySize(g_liquidity)-1;i>=MathMax(0,ArraySize(g_liquidity)-3);i--)
      if(g_liquidity[i].swept){MarkSignalFactor(FLAG_LIQUIDITY,BIT_LIQUIDITY); break;}
   for(int i=0;i<ArraySize(g_fvgs);i++)
      if(g_fvgs[i].state=="OPEN"){MarkSignalFactor(FLAG_FVG,BIT_FVG); break;}
   if(g_range.valid)
   {
      double ot=0,ob=0; bool ib=false;
      if(GetOTEZone(ot,ob,ib))
         if(price<=ot && price>=ob) MarkSignalFactor(FLAG_OTE,BIT_OTE);
   }
   if(g_htf_bias!=0) MarkSignalFactor(FLAG_HTF_BIAS,BIT_HTF_BIAS);
   MqlDateTime st; TimeToStruct(g_buf_t[g_rates_total-2],st);
   int hr=st.hour;
   if((hr>=InpLondonStart && hr<InpLondonStart+3) || (hr>=InpNewYorkStart && hr<InpNewYorkStart+3))
      MarkSignalFactor(FLAG_KILLZONE,BIT_KILLZONE);
   for(int i=0;i<ArraySize(g_zones);i++)
   {
      if(g_zones[i].state=="MITIGATED") continue;
      if(price<=g_zones[i].top && price>=g_zones[i].bottom)
      {
         if(g_zones[i].bullish) MarkSignalFactor(FLAG_DEMAND_ZONE,BIT_DEMAND_ZONE);
         else                   MarkSignalFactor(FLAG_SUPPLY_ZONE,BIT_SUPPLY_ZONE);
      }
   }
   if(g_judas!=0) MarkSignalFactor(FLAG_JUDAS,BIT_JUDAS);
   if(DebugMode)
   {
      string path_log="[SignalMask] path=";
      path_log+=(InpUseBitMasking?"BITMASK":"BOOL FLAGS");
      path_log+=" closed="+IntegerToString(total-2);
      path_log+=" structure=";
      path_log+=(IsLatestStructureConfirmed(total-2)?"confirmed":"pending/none");
      DebugPrint(path_log);
   }
}
bool CheckSignalPattern(const int required_mask)
{
   if(InpUseBitMasking) return (g_signal_mask & required_mask)==required_mask;
   // Boolean path: decode the existing BIT_* caller contract arithmetically,
   // so not even combined patterns need a bitwise operation when disabled.
   if(required_mask<0) return false;
   int remaining=required_mask;
   for(int i=0;i<FLAG_COUNT;i++)
   {
      if(remaining%2!=0 && !g_signal_flags[i]) return false;
      remaining/=2;
   }
   return remaining==0; // unknown required bits are never treated as present
}
void AddGraphNode(const string type,const double price,const int strength)
{
   int idx=ArraySize(g_market_graph);
   ArrayResize(g_market_graph,idx+1,32);
   g_market_graph[idx].type=type;
   g_market_graph[idx].price=price;
   g_market_graph[idx].strength=strength;
   g_market_graph[idx].link_count=0;
   g_market_graph[idx].visited=false;
}
void ConnectGraphNodes()
{
   int n=ArraySize(g_market_graph);
   double max_distance=(g_atr>0)? g_atr*0.75 : 200*_Point;
   for(int i=0;i<n;i++)
      for(int j=i+1;j<n;j++)
      {
         if(MathAbs(g_market_graph[i].price-g_market_graph[j].price)>max_distance) continue;
         if(g_market_graph[i].link_count<MAX_GRAPH_LINKS) g_market_graph[i].links[g_market_graph[i].link_count++]=j;
         if(g_market_graph[j].link_count<MAX_GRAPH_LINKS) g_market_graph[j].links[g_market_graph[j].link_count++]=i;
      }
}
void BuildMarketGraph()
{
   // P2.11 Simplified: cap nodes, reduce links for performance
   ArrayResize(g_market_graph,0,32);
   int maxNodes=14;
   int cnt=0;
   // limit OBs to strongest 6
   BuildOBStrengthIndex();
   for(int k=0;k<MathMin(6, ArraySize(g_order_blocks)) && cnt<maxNodes;k++)
   {
      int i=g_ob_strength_idx[k];
      if(i<0 || i>=ArraySize(g_order_blocks)) continue;
      AddGraphNode("OB",OBMid(i),g_order_blocks[i].strength); cnt++;
   }
   for(int i=0;i<ArraySize(g_fvgs) && cnt<maxNodes;i++) if(g_fvgs[i].state!="FILLED"){ AddGraphNode("FVG",(g_fvgs[i].top+g_fvgs[i].bottom)*0.5,3); cnt++; }
   for(int i=0;i<ArraySize(g_liquidity) && cnt<maxNodes;i++) if(g_liquidity[i].swept){ AddGraphNode("LIQ",g_liquidity[i].price,5); cnt++; if(cnt>=maxNodes) break; }
   // reduced connect radius and max links already limited to 6 via MAX_GRAPH_LINKS
   ConnectGraphNodes();
}
double GraphConfluenceScore(const double price)
{
   int n=ArraySize(g_market_graph);
   if(n==0) return 0.0;
   double band=(g_atr>0)? g_atr*2.0 : 300*_Point;
   double best=0.0;
   for(int i=0;i<n;i++)
   {
      if(MathAbs(g_market_graph[i].price-price)>band) continue;
      double v=10.0*(1+g_market_graph[i].link_count)+g_market_graph[i].strength*4.0;
      best=MathMax(best,v);
   }
   return MathMin(100.0,best);
}
int KnapsackOptimizeSignals(SSignalFactor &factors[],const int max_weight)
{
   if(!InpUseKnapsack || max_weight<=0) return 0;
   int n=ArraySize(factors);
   int dp[]; ArrayResize(dp,max_weight+1); ArrayInitialize(dp,0);
   for(int i=0;i<n;i++)
   {
      if(!factors[i].active) continue;
      int w=factors[i].weight; int v=factors[i].value;
      if(w<=0 || w>max_weight) continue;
      for(int cap=max_weight;cap>=w;cap--) dp[cap]=MathMax(dp[cap],dp[cap-w]+v);
   }
   return dp[max_weight];
}
int DynamicProgrammingConfidence(SSignalFactor &factors[])
{
   if(!InpUseDynamicProg) return 0;
   int n=ArraySize(factors);
   int dp[]; ArrayResize(dp,101); ArrayInitialize(dp,0);
   for(int i=0;i<n;i++)
   {
      if(!factors[i].active) continue;
      int w=factors[i].weight;
      if(w<=0 || w>100) continue;
      for(int j=100;j>=w;j--) dp[j]=MathMax(dp[j],dp[j-w]+factors[i].value);
   }
   return dp[100];
}

//====================================================================
// QUALITY ENGINE - 7 WEIGHTED PILLARS
//====================================================================
double ScoreStructure(const int total,const bool is_buy)
{
   int n=ArraySize(g_structures);
   if(n==0) return 0.0;
   SStructureBreak s=g_structures[n-1];
   if(s.bullish!=is_buy) return 0.0;
   double base=(s.type=="MSS")?100.0:(s.type=="BOS"?78.0:60.0);
   int age=total-1-s.bar;
   if(InpMaxStructureAge>0)
   {
      double decay=1.0-(double)age/(double)(InpMaxStructureAge*3);
      base*=MathMax(0.50,MathMin(1.0,decay));
   }
   return base;
}
double ScoreLiquidity(const bool is_buy)
{
   int n=ArraySize(g_liquidity);
   double best=0.0;
   int scanned=0;
   for(int i=n-1;i>=0 && scanned<15;i--,scanned++)
   {
      if(g_liquidity[i].swept)
      {
         bool aligned=(is_buy && StringFind(g_liquidity[i].type,"SSL")>=0) || (!is_buy && StringFind(g_liquidity[i].type,"BSL")>=0);
         best=MathMax(best,aligned?100.0:70.0);
      }
      else if(g_liquidity[i].type=="EQH" || g_liquidity[i].type=="EQL")
         best=MathMax(best,50.0);
   }
   return best;
}
double ScoreOrderBlock(const int ob_index,const double price,const double atr)
{
   if(ob_index<0 || ob_index>=ArraySize(g_order_blocks)) return 0.0;
   if(g_order_blocks[ob_index].state=="MITIGATED") return 0.0;
   double s=(g_order_blocks[ob_index].strength>=5)?100.0:(g_order_blocks[ob_index].strength>=4)?85.0:65.0;
   if(g_order_blocks[ob_index].state=="TOUCHED") s*=(InpRelaxedMode?0.92:0.85);
   double dist=MathAbs(price-OBMid(ob_index));
   if(atr>0) s*=MathMax(0.40,1.0-(dist/(atr*8.0)));
   return MathMin(100.0,s);
}
double ScoreFVG(const bool is_buy,const double price)
{
   double best=0.0;
   int fvg_count=0;
   for(int i=0;i<ArraySize(g_fvgs);i++)
   {
      if(g_fvgs[i].state=="FILLED") continue;
      if(g_fvgs[i].bullish!=is_buy) continue;
      fvg_count++;
      double v=(g_fvgs[i].state=="OPEN")?80.0:(InpAllowPartialFVG?65.0:50.0);
      if(price<=g_fvgs[i].top && price>=g_fvgs[i].bottom) v=100.0;
      best=MathMax(best,v);
   }
   if(DebugMode && fvg_count>0)
      Print(StringFormat(">>> FVG Score: %.1f (%d %s FVGs)",best,fvg_count,is_buy?"bullish":"bearish"));
   return best;
}
double ScoreSession()
{
   MqlDateTime st; TimeToStruct(g_buf_t[g_rates_total-2],st);
   int hr=st.hour;
   if((hr>=InpLondonStart && hr<InpLondonStart+3) || (hr>=InpNewYorkStart && hr<InpNewYorkStart+3)) return 100.0;
   if((hr>=InpLondonStart && hr<InpLondonEnd) || (hr>=InpNewYorkStart && hr<InpNewYorkEnd)) return 75.0;
   if(hr>=InpAsianStart && hr<InpAsianEnd) return 40.0;
   return 30.0;
}
double ScoreHTF(const bool is_buy)
{
   if(!InpUseHTFBias) return 50.0;
   if(g_htf_bias==0) return 50.0;
   return (g_htf_bias==(is_buy?1:-1))?100.0:0.0;
}
double ScoreAlgo(const int knap,const int dp,const int max_possible,const double price)
{
   double a=(max_possible>0)?100.0*knap/max_possible:0.0;
   double b=(max_possible>0)?100.0*dp/max_possible:0.0;
   double base=MathMax(a,b);
   double conf=InpUseGraphTheory?GraphConfluenceScore(price):0.0;
   return MathMin(100.0,base*0.70+conf*0.30);
}
int MaxPossibleValue(SSignalFactor &f[])
{
   int sum=0;
   for(int i=0;i<ArraySize(f);i++) sum+=f[i].value;
   return MathMax(1,sum);
}
int CalculateEvidenceScore(const int conf,const int knap,const int dp,const int maxp)
{
   double kn=(maxp>0)?100.0*knap/maxp:0.0;
   double dn=(maxp>0)?100.0*dp/maxp:0.0;
   double prob=conf*0.50+kn*0.30+dn*0.20;
   if(g_htf_bias!=0) prob+=4;
   if(CheckSignalPattern(BIT_KILLZONE)) prob+=3;
   if(g_judas!=0) prob+=2;
   if(CheckSignalPattern(BIT_MSS|BIT_STRONG_OB|BIT_LIQUIDITY|BIT_OTE)) prob+=5;
   if(!InpIgnoreSpreadOffHours && !(g_is_backtest && InpIgnoreSpreadInBacktest) && g_spread>InpMaxSpreadPts) prob-=10;
   if(g_adx>0 && g_adx<InpADXChopLevel) prob-=4;
   return (int)MathMax(0,MathMin(100,MathRound(prob)));
}
string CalculateQualityGrade(const int conf,const int prob)
{
   int s=(int)MathRound(conf*0.60+prob*0.40);
   bool perfect=CheckSignalPattern(BIT_MSS|BIT_STRONG_OB|BIT_LIQUIDITY|BIT_OTE);
   if(s>=90 && perfect) return "A+";
   if(s>=85) return "A";
   if(s>=72) return "B";
   if(s>=60) return "C";
   return "D";
}
int GradeRank(const string g)
{
   if(g=="A+") return 5;
   if(g=="A") return 4;
   if(g=="B") return 3;
   if(g=="C") return 2;
   return 1;
}
string GetInstitutionalGrade(const int conf,const int knap,const int dp,const int maxp)
{
   double kn=(maxp>0)?100.0*knap/maxp:0.0;
   double dn=(maxp>0)?100.0*dp/maxp:0.0;
   int t=(int)MathRound((conf+kn+dn)/3.0);
   if(t>=85) return "Institutional";
   if(t>=68) return "Professional";
   return "Retail";
}
string CalculateRiskLevel(const double entry,const double sl,const double atr,const long spread_pts,double &risk_pips_out)
{
   double pip=PipSize();
   double risk=MathAbs(entry-sl);
   risk_pips_out=(pip>0)?risk/pip:0.0;
   double atr_mult=(atr>0)?risk/atr:99.0;
   double sp_ratio=(risk>0)?(spread_pts*_Point)/risk:1.0;
   int pts=0;
   if(atr_mult<=1.20) pts+=2; else if(atr_mult<=2.00) pts+=1;
   if(sp_ratio<=0.08) pts+=2; else if(sp_ratio<=0.15) pts+=1;
   if(spread_pts<=InpMaxSpreadPts/2) pts+=1;
   if(pts>=4) return "LOW";
   if(pts>=2) return "MEDIUM";
   return "HIGH";
}
string BuildConfidenceBar(const int pct,const int cells=10)
{
   int filled=(int)MathRound((double)pct/100.0*cells);
   filled=MathMax(0,MathMin(cells,filled));
   string full=InpASCIIBar?"#":"█";
   string empt=InpASCIIBar?"-":"░";
   string bar="";
   for(int i=0;i<filled;i++) bar+=full;
   for(int i=filled;i<cells;i++) bar+=empt;
   return bar;
}
//--------------------------------------------------------------------
int SelectEntryOB(const double price,const bool is_buy,const double atr)
{
   int n=ArraySize(g_order_blocks);
   if(n==0)
   {
      g_ob_search_path=InpUseBinarySearch?"skipped (no OB; binary configured)":"skipped (no OB; linear configured)";
      DebugPrint(">>> OB Search path: "+g_ob_search_path);
      return -1;
   }
   double a=(atr>0)?atr:_Point*100;
   double max_dist=InpRelaxedMode ? a*12.0 : a*InpMaxOBDistATR;
   int first=0,after=n,nearest_pos=-1;
   if(InpUseBinarySearch && ArraySize(g_ob_price_idx)!=n) BuildOBPriceIndex();
   bool indexed=(InpUseBinarySearch && ArraySize(g_ob_price_idx)==n);
   if(indexed)
   {
      int nearest=BinarySearchNearestOB(price,nearest_pos);
      if(nearest<0 || nearest_pos<0) indexed=false;
      else
      {
         // Range by midpoint; evaluate EVERY eligible candidate with the
         // original strength/distance/mitigation/direction rules below.
         first=nearest_pos; after=nearest_pos+1;
         while(first>0 && MathAbs(price-OBMid(g_ob_price_idx[first-1]))<=max_dist) first--;
         while(after<n && MathAbs(price-OBMid(g_ob_price_idx[after]))<=max_dist) after++;
      }
   }
   g_ob_search_path=indexed?"binary price-index":"linear scan";
   if(InpUseBinarySearch && !indexed) g_ob_search_path+=" (index unavailable)";
   int best=-1; double best_score=-DBL_MAX;
   int candidates=0;
   for(int k=first;k<after;k++)
   {
      int i=indexed?g_ob_price_idx[k]:k;
      if(g_order_blocks[i].bullish!=is_buy) continue;
      if(g_order_blocks[i].state=="MITIGATED") continue;
      double mid=OBMid(i);
      double dist=MathAbs(price-mid);
      if(dist>max_dist) continue;
      if(!InpRelaxedMode)
      {
         if(is_buy && mid>price + a*0.5) continue;
         if(!is_buy && mid<price - a*0.5) continue;
      }
      candidates++;
      double dscore=MathMax(0.0,100.0-(dist/a)*12.0);
      double score=g_order_blocks[i].strength*15.0+dscore;
      if(g_order_blocks[i].state=="TOUCHED") score*=(InpRelaxedMode?0.95:0.85);
      // The binary traversal is price-ordered, not chronological: preserve
      // the linear path's oldest-master-index winner when scores tie.
      if(score>best_score || (score==best_score && (best<0 || i<best)))
      {best_score=score; best=i;}
   }
   if(DebugMode || InpShowDebugAlerts)
   {
      Print(">>> OB Search path: ",g_ob_search_path," | scanned ",after-first,"/",n);
      Print(StringFormat(">>> OB Search for %s:",is_buy?"BUY":"SELL"));
      Print(StringFormat(" Total OBs: %d | Candidates: %d",n,candidates));
      if(best>=0)
         Print(StringFormat(" Selected OB #%d (%s) | Strength: %d | Score: %.1f | Dist: %.2f ATR",best,g_order_blocks[best].id,g_order_blocks[best].strength,best_score,MathAbs(price-OBMid(best))/a));
      else
         Print(StringFormat(" No OB selected (max_dist: %.1f ATR)",max_dist/a));
   }
   return best;
}
//--------------------------------------------------------------------
void PushTarget(STarget &arr[],STarget &t)
{
   int i=ArraySize(arr); ArrayResize(arr,i+1,16); arr[i]=t;
}
double GreedyFindBestTarget(const double from,const bool is_buy,const double min_dist,string &type_out)
{
   type_out="ATR Projection";
   STarget tg[]; ArrayResize(tg,0,16);
   for(int i=0;i<ArraySize(g_liquidity);i++)
   {
      double p=g_liquidity[i].price;
      if(!((is_buy && p>from+min_dist) || (!is_buy && p<from-min_dist))) continue;
      STarget t; t.price=p;
      if(g_liquidity[i].swept){t.priority=10; t.type="Swept Liq";}
      else if(g_liquidity[i].type=="EQH" || g_liquidity[i].type=="EQL"){t.priority=8; t.type=g_liquidity[i].type+" Pool";}
      else continue;
      PushTarget(tg,t);
   }
   for(int i=0;i<ArraySize(g_order_blocks);i++)
   {
      if(g_order_blocks[i].bullish==is_buy) continue;
      double p=is_buy?g_order_blocks[i].bottom:g_order_blocks[i].top;
      if(!((is_buy && p>from+min_dist) || (!is_buy && p<from-min_dist))) continue;
      STarget t; t.price=p; t.priority=7; t.type="Opposing OB"; PushTarget(tg,t);
   }
   for(int i=0;i<ArraySize(g_fvgs);i++)
   {
      if(g_fvgs[i].state=="FILLED") continue;
      double p=is_buy?g_fvgs[i].bottom:g_fvgs[i].top;
      if(!((is_buy && p>from+min_dist) || (!is_buy && p<from-min_dist))) continue;
      STarget t; t.price=p; t.priority=6; t.type="FVG Edge"; PushTarget(tg,t);
   }
   double mag[2]; string mn[2];
   // use cached D1 levels if available
   mag[0]=g_d1_high; mn[0]="PDH";
   mag[1]=g_d1_low; mn[1]="PDL";
   for(int k=0;k<2;k++)
   {
      double p=mag[k]; if(p<=0) continue;
      if(!((is_buy && p>from+min_dist) || (!is_buy && p<from-min_dist))) continue;
      STarget t; t.price=p; t.priority=(k<2)?5:4; t.type=mn[k]; PushTarget(tg,t);
   }
   if(ArraySize(tg)==0) return 0.0;
   int best=0;
   for(int i=1;i<ArraySize(tg);i++)
   {
      if(tg[i].priority>tg[best].priority){best=i; continue;}
      if(tg[i].priority==tg[best].priority)
      {
         if(is_buy && tg[i].price<tg[best].price) best=i;
         if(!is_buy && tg[i].price>tg[best].price) best=i;
      }
   }
   type_out=tg[best].type;
   return tg[best].price;
}

//====================================================================
// DECISION ENGINE
//====================================================================
void AddReason(const string r)
{
   if(g_trade_setup.reason_count<14) g_trade_setup.reasons[g_trade_setup.reason_count++]=r;
}
void AddBlocker(const string b)
{
   if(g_trade_setup.blocker_count<10) g_trade_setup.blockers[g_trade_setup.blocker_count++]=b;
}
void CalculateAITradeSetup(const int total,const double &o[],const double &h[],const double &l[],const double &c[])
{
   // preserve previous valid if lifecycle disabled? handled by caller
   g_trade_setup.valid=false;
   g_trade_setup.reason_count=0;
   g_trade_setup.blocker_count=0;
   g_trade_setup.confidence=0;
   g_trade_setup.knapsack_score=0;
   g_trade_setup.dp_optimal_score=0;
   g_trade_setup.weighted_score=0;
   g_trade_setup.evidence_score=0;
   g_trade_setup.quality_grade="D";
   g_trade_setup.institutional_grade="Retail";
   g_trade_setup.risk_level="HIGH";
   g_trade_setup.risk_pips=0.0;
   g_trade_setup.rr1=g_trade_setup.rr2=g_trade_setup.rr3=0.0;
   g_trade_setup.ob_index=-1;
   g_trade_setup.ob_uid="";
   g_trade_setup.ob_dist_atr=0.0;
   g_score.structure=g_score.liquidity=g_score.orderblock=0;
   g_score.fvg=g_score.session=g_score.htf=g_score.algo=0;
   g_score.final_score=0;
   g_ob_search_path="skipped (no confirmed structure)";
   if(ArraySize(g_structures)==0)
   {
      AddBlocker("No structure detected");
      DebugPrint("========== SIGNAL CHECK ==========\nMarket Structure: FAIL\nRight Confirm   : FAIL (no break detected)\nFINAL           : REJECTED\nREASON          : No BOS/CHoCH/MSS detected\n==================================");
      return;
   }
   if(total<3) return;
   SStructureBreak last_str=g_structures[ArraySize(g_structures)-1];
   bool is_buy=last_str.bullish;
   //--- v5.7.0: the engine runs once per CLOSED bar -> reference price is the
   //    last closed close (bar 1), never the forming bar (bar 0).
   int    closed_bar=total-2;
   double price=c[closed_bar];
   double atr_val=g_atr;
   int    struct_age=closed_bar-last_str.bar;
   bool gate_right_confirm=IsLatestStructureConfirmed(closed_bar);
   if(!gate_right_confirm)
   {
      AddBlocker(StringFormat("Right confirmation %d/%d closed bars after break",struct_age,InpMinRightConfirmBars));
      if(DebugMode)
         Print(StringFormat("========== SIGNAL CHECK ==========\nBar (closed)    : %d\nMarket Structure: FAIL (%s%s pending)\nRight Confirm   : FAIL (%d < %d additional closed bars after break bar %d)\nFINAL           : REJECTED\nREASON          : Break not yet eligible for setup\n==================================",
               closed_bar,last_str.type,is_buy?"+":"-",struct_age,InpMinRightConfirmBars,last_str.bar));
      return; // pending structure cannot seed/replace a setup or influence scoring
   }
   SSignalFactor f[]; ArrayResize(f,11);
   f[0].name="MSS"; f[0].value=25; f[0].weight=5; f[0].active=(last_str.type=="MSS");
   f[1].name="BOS"; f[1].value=20; f[1].weight=4; f[1].active=(last_str.type=="BOS");
   f[2].name="CHoCH"; f[2].value=15; f[2].weight=3; f[2].active=(last_str.type=="CHoCH");
   f[3].name="Strong OB"; f[3].value=20; f[3].weight=5; f[3].active=false;
   for(int i=0;i<ArraySize(g_order_blocks);i++) if(g_order_blocks[i].strength>=4 && g_order_blocks[i].state!="MITIGATED"){f[3].active=true; break;}
   f[4].name="FVG Open"; f[4].value=10; f[4].weight=2; f[4].active=false;
   for(int i=0;i<ArraySize(g_fvgs);i++) if((g_fvgs[i].state=="OPEN" || (InpAllowPartialFVG && g_fvgs[i].state=="PARTIAL")) && g_fvgs[i].bullish==is_buy){f[4].active=true; break;}
   f[5].name="Liquidity Taken"; f[5].value=15; f[5].weight=4; f[5].active=false;
   for(int i=ArraySize(g_liquidity)-1;i>=MathMax(0,ArraySize(g_liquidity)-3);i--) if(g_liquidity[i].swept){f[5].active=true; break;}
   f[6].name="OTE Zone"; f[6].value=15; f[6].weight=4; f[6].active=CheckSignalPattern(BIT_OTE);
   f[7].name="HTF Bias"; f[7].value=10; f[7].weight=3; f[7].active=(InpUseHTFBias && g_htf_bias!=0 && g_htf_bias==(is_buy?1:-1));
   f[8].name="Judas Swing"; f[8].value=10; f[8].weight=3; f[8].active=(InpDetectJudas && g_judas!=0 && g_judas==(is_buy?1:-1));
   f[9].name="Kill Zone"; f[9].value=10; f[9].weight=2; f[9].active=CheckSignalPattern(BIT_KILLZONE);
   // v5.7.0 (BUY/SELL symmetry): BUY looks for a Demand zone, SELL for a Supply zone
   f[10].name=is_buy?"Demand Zone":"Supply Zone"; f[10].value=10; f[10].weight=2;
   f[10].active=is_buy ? CheckSignalPattern(BIT_DEMAND_ZONE) : CheckSignalPattern(BIT_SUPPLY_ZONE);
   int active_factors=0;
   for(int i=0;i<ArraySize(f);i++) if(f[i].active){active_factors++; AddReason("+ "+f[i].name);}
   if(InpLogSignalDetails || DebugMode) Print(StringFormat(">>> [%s] Active Factors: %d/%d (min required: %d) | last structure %s%s age %d bars",is_buy?"BUY":"SELL",active_factors,ArraySize(f),InpMinSignalFactors,last_str.type,is_buy?"+":"-",struct_age));
   int maxp=MaxPossibleValue(f);
   g_trade_setup.max_factor_value=maxp;
   g_trade_setup.knapsack_score=KnapsackOptimizeSignals(f,30);
   g_trade_setup.dp_optimal_score=DynamicProgrammingConfidence(f);
   int ob_idx=SelectEntryOB(price,is_buy,atr_val);
   if(ob_idx>=0) g_trade_setup.ob_uid=g_order_blocks[ob_idx].id;
   g_trade_setup.ob_index=ob_idx;
   g_score.structure=ScoreStructure(total,is_buy);
   g_score.liquidity=ScoreLiquidity(is_buy);
   g_score.orderblock=ScoreOrderBlock(ob_idx,price,atr_val);
   g_score.fvg=ScoreFVG(is_buy,price);
   g_score.session=ScoreSession();
   g_score.htf=ScoreHTF(is_buy);
   g_score.algo=ScoreAlgo(g_trade_setup.knapsack_score,g_trade_setup.dp_optimal_score,maxp,price);
   g_score.final_score=g_score.structure*0.25 + g_score.liquidity*0.20 + g_score.orderblock*0.20 + g_score.fvg*0.10 + g_score.session*0.10 + g_score.htf*0.10 + g_score.algo*0.05;
   if(g_adx>=InpADXTrendLevel){g_score.final_score+=3; AddReason(StringFormat("+ ADX %.1f Trending",g_adx));}
   else if(g_adx>0 && g_adx<InpADXChopLevel){g_score.final_score-=6; AddBlocker(StringFormat("ADX %.1f CHOP",g_adx));}
   if(ob_idx>=0)
   {
      g_trade_setup.ob_dist_atr=(atr_val>0)?MathAbs(price-OBMid(ob_idx))/atr_val:0.0;
      AddReason(StringFormat("+ OB #%d %s @%.1f ATR",g_order_blocks[ob_idx].strength,g_order_blocks[ob_idx].state,g_trade_setup.ob_dist_atr));
   }
   else if(InpRequireOB)
   {
      AddBlocker(StringFormat("No OB within %.1f ATR",InpRelaxedMode?12.0:InpMaxOBDistATR));
   }
   bool spread_ok;
   if(g_is_backtest && InpIgnoreSpreadInBacktest)
   {
      spread_ok=true;
      DebugPrint(">>> Spread check bypassed (Backtest mode)");
   }
   else
   {
      spread_ok=InpIgnoreSpreadOffHours ? true : (g_spread<=InpMaxSpreadPts);
   }
   if(!spread_ok){g_score.final_score-=12; AddBlocker(StringFormat("SPREAD %d > %d pts",(int)g_spread,InpMaxSpreadPts));}
   int score=(int)MathMax(0,MathMin(100,MathRound(g_score.final_score)));
   g_trade_setup.weighted_score=score;
   g_trade_setup.confidence=score;
   g_trade_setup.evidence_score=CalculateEvidenceScore(score,g_trade_setup.knapsack_score,g_trade_setup.dp_optimal_score,maxp);
   g_trade_setup.quality_grade=CalculateQualityGrade(score,g_trade_setup.evidence_score);
   g_trade_setup.institutional_grade=GetInstitutionalGrade(score,g_trade_setup.knapsack_score,g_trade_setup.dp_optimal_score,maxp);
   int min_conf=InpRelaxedMode?45:InpMinConfidenceScore;
   int min_prob=InpRelaxedMode?50:InpMinProbability;

   //================================================================
   // SIGNAL ENGINE - readable components (v5.7.0)
   //   1. Market context  : last closed structure event (direction = is_buy)
   //   2. HTF bias        : D1 + InpHTFBiasTF agreement (hard gate only if InpRequireHTFBias)
   //   3. Liquidity/sweep : factor f[5] (informational unless it moves the score)
   //   4. Structure age   : setup must be seedable before the retest timeout kills it
   //   5. Entry zone      : OB (hard gate only if InpRequireOB), else FVG/zone/synthetic
   //   6. Filters         : spread, score, probability, grade, factor count
   //   7. Final           : all hard gates PASS -> candidate levels -> lifecycle
   //================================================================
   bool ctx_htf_aligned   = (g_htf_bias!=0 && g_htf_bias==(is_buy?1:-1));
   bool ctx_liq_swept     = f[5].active;
   bool ctx_fvg           = f[4].active;
   bool ctx_ote           = f[6].active;
   bool ctx_killzone      = f[9].active;
   bool ctx_zone          = f[10].active;
   bool ctx_ob_found      = (ob_idx>=0);

   bool gate_score  =(score>=min_conf);
   bool gate_prob   =(g_trade_setup.evidence_score>=min_prob);
   bool gate_grade  =(!InpBlockLowGrade || GradeRank(g_trade_setup.quality_grade)>=(int)InpMinGrade);
   bool gate_ob     =true;
   if(InpRequireOB)
      gate_ob=(ob_idx>=0 && g_order_blocks[ob_idx].strength>=InpMinEntryOBStrength && g_order_blocks[ob_idx].state!="MITIGATED");
   bool gate_htf    =true;
   if(InpRequireHTFBias) gate_htf=ctx_htf_aligned;
   bool gate_factors=(active_factors>=InpMinSignalFactors);
   // v5.7.0 (R9): in lifecycle mode a setup created from a structure older than
   // the retest timeout was seeded, invalidated on the very next lifecycle pass and
   // blacklisted (poisoning later ideas). Reject it up-front with an explicit reason.
   bool gate_age    =(!InpUseRetestLifecycle || InpRetestTimeoutBars<=0 || struct_age<=InpRetestTimeoutBars);

   if(!gate_score)   AddBlocker(StringFormat("Score %d < %d",score,min_conf));
   if(!gate_prob)    AddBlocker(StringFormat("Evidence %d < %d",g_trade_setup.evidence_score,min_prob));
   if(!gate_grade)   AddBlocker(StringFormat("Grade %s below %s",g_trade_setup.quality_grade,EnumToString((ENUM_MIN_GRADE)InpMinGrade)));
   if(!gate_ob && InpRequireOB) AddBlocker("No valid Order Block (required)");
   if(!gate_htf && InpRequireHTFBias) AddBlocker("No HTF Bias alignment (required)");
   if(!gate_factors) AddBlocker(StringFormat("Only %d/%d factors (min %d)",active_factors,ArraySize(f),InpMinSignalFactors));
   if(!gate_age)     AddBlocker(StringFormat("Structure age %d > %d bars",struct_age,InpRetestTimeoutBars));

   bool all_gates = gate_right_confirm && gate_score && gate_prob && gate_grade && gate_ob && gate_htf && gate_factors && gate_age && spread_ok;

   if(DebugMode)
   {
      string dir=is_buy?"BUY":"SELL";
      string reason="";
      if(!spread_ok)        reason="Spread filter failed";
      else if(!gate_age)    reason="Structure too old for retest lifecycle";
      else if(!gate_htf)    reason="HTF bias alignment failed (required)";
      else if(!gate_ob)     reason="Order Block gate failed (required)";
      else if(!gate_factors)reason="Not enough confluence factors";
      else if(!gate_score)  reason="Confidence score below minimum";
      else if(!gate_prob)   reason="Evidence score below minimum";
      else if(!gate_grade)  reason="Quality grade below minimum";
      string tbl="";
      tbl+="\n========== "+dir+" CHECK ==========";
      tbl+=StringFormat("\nBar (closed)    : %d  %s",closed_bar,TimeToString(g_buf_t[closed_bar],TIME_DATE|TIME_MINUTES));
      tbl+=StringFormat("\nMarket Structure: PASS  (%s%s age %d)",last_str.type,is_buy?"+":"-",struct_age);
      tbl+=StringFormat("\nRight Confirm   : %s  (%d >= %d closed bars after break)",PF(gate_right_confirm),struct_age,InpMinRightConfirmBars);
      tbl+=StringFormat("\nMask Path       : PASS  (%s)",InpUseBitMasking?"BITMASK":"BOOL FLAGS");
      tbl+=StringFormat("\nOB Search Path  : %s  (%s)",ArraySize(g_order_blocks)>0?"PASS":"SKIPPED",g_ob_search_path);
      tbl+=StringFormat("\nStructure Age   : %s  (%d <= %d)",PF(gate_age),struct_age,InpRetestTimeoutBars);
      tbl+=StringFormat("\nHTF Bias        : %s  (bias=%s, required=%s)",PF(!InpRequireHTFBias || ctx_htf_aligned),g_htf_bias==1?"BULL":(g_htf_bias==-1?"BEAR":"NEUTRAL"),InpRequireHTFBias?"yes":"no");
      tbl+=StringFormat("\nLiquidity Sweep : %s  (factor)",PF(ctx_liq_swept));
      tbl+=StringFormat("\nDisplacement    : %s  (structure strength %d)",PF(last_str.strength>=5),last_str.strength);
      tbl+=StringFormat("\nFVG             : %s  (factor)",PF(ctx_fvg));
      tbl+=StringFormat("\nOrder Block     : %s  (%s)",PF(gate_ob),ctx_ob_found?StringFormat("OB str %d @ %.2f ATR",g_order_blocks[ob_idx].strength,g_trade_setup.ob_dist_atr):"none within range");
      tbl+=StringFormat("\nPremium/Disc OTE: %s  (factor)",PF(ctx_ote));
      tbl+=StringFormat("\n%s: %s  (factor)",is_buy?"Demand Zone     ":"Supply Zone     ",PF(ctx_zone));
      tbl+=StringFormat("\nKill Zone       : %s  (factor)",PF(ctx_killzone));
      tbl+=StringFormat("\nADX             : %.1f %s",g_adx,(g_adx>0 && g_adx<InpADXChopLevel)?"(CHOP penalty)":"");
      tbl+=StringFormat("\nSpread Filter   : %s  (%d pts, max %d)",PF(spread_ok),(int)g_spread,InpMaxSpreadPts);
      tbl+=StringFormat("\nFactors         : %s  (%d >= %d)",PF(gate_factors),active_factors,InpMinSignalFactors);
      tbl+=StringFormat("\nScore           : %s  (%d >= %d)",PF(gate_score),score,min_conf);
      tbl+=StringFormat("\nEvidence score  : %s  (%d >= %d)",PF(gate_prob),g_trade_setup.evidence_score,min_prob);
      tbl+=StringFormat("\nGrade           : %s  (%s)",PF(gate_grade),g_trade_setup.quality_grade);
      tbl+=StringFormat("\n\nFINAL %-10s: %s",dir,all_gates?"ACCEPTED -> candidate levels":"REJECTED");
      if(!all_gates) tbl+="\nREASON          : "+reason;
      tbl+="\n===============================";
      Print(tbl);
   }

   if(!all_gates)
   {
      if(InpShowDebugAlerts)
      {
         Print("=========================================");
         Print(" SIGNAL BLOCKED");
         Print("=========================================");
         for(int i=0;i<g_trade_setup.blocker_count;i++) Print(" ",g_trade_setup.blockers[i]);
         Print("=========================================");
      }
      return;
   }
   //================ candidate levels (entry/SL/TP) with fallback zone
   double entry_price=0;
   double sl_price=0;
   double buf=(atr_val>0)?atr_val*InpSLBufferATR:0.0;
   double zone_top=0, zone_bottom=0;
   double min_zone_h = (atr_val>0 ? atr_val*0.5 : 8*PipSize());
   if(ob_idx>=0)
   {
      SOrderBlock ob=g_order_blocks[ob_idx];
      entry_price=InpUseMeanThreshold ? (ob.top+ob.bottom)*0.5 : (is_buy?ob.top:ob.bottom);
      sl_price=is_buy?ob.bottom:ob.top;
      zone_top=ob.top; zone_bottom=ob.bottom;
      if(InpIntersectFVGZone)
      {
         for(int i=0;i<ArraySize(g_fvgs);i++)
         {
            if(g_fvgs[i].state=="FILLED")            continue;
            if(g_fvgs[i].bullish!=is_buy)            continue;
            bool overlap=!(g_fvgs[i].bottom>zone_top || g_fvgs[i].top<zone_bottom);
            if(!overlap) continue;
            double it = MathMin(zone_top, g_fvgs[i].top);
            double ib = MathMax(zone_bottom, g_fvgs[i].bottom);
            if(it>ib) { zone_top=it; zone_bottom=ib; }
            break;
         }
      }
      // ensure min height after intersection
      if((zone_top-zone_bottom) < min_zone_h)
      {
         double mid=(zone_top+zone_bottom)*0.5;
         zone_top=mid+min_zone_h*0.5;
         zone_bottom=mid-min_zone_h*0.5;
      }
      if(InpSLBeyondSweep)
      {
         int n=ArraySize(g_liquidity);
         for(int i=n-1;i>=0 && i>n-12;i--)
         {
            if(!g_liquidity[i].swept) continue;
            if(is_buy && StringFind(g_liquidity[i].type,"SSL")>=0) sl_price=MathMin(sl_price,g_liquidity[i].price);
            if(!is_buy && StringFind(g_liquidity[i].type,"BSL")>=0) sl_price=MathMax(sl_price,g_liquidity[i].price);
         }
      }
      entry_price=(zone_top+zone_bottom)*0.5;
      sl_price=is_buy?sl_price-buf:sl_price+buf;
   }
   else
   {
      //--- P2.10 Enhanced synthetic fallback: scored FVG/Zone, premium-aware synthetic
      bool found=false;
      // Score FVG candidates: closest + smallest height bonus
      int bestFVG=-1; double bestFvgScore=DBL_MAX;
      for(int i=0;i<ArraySize(g_fvgs);i++)
      {
         if(g_fvgs[i].state=="FILLED") continue;
         if(g_fvgs[i].bullish!=is_buy) continue;
         double midF=(g_fvgs[i].top+g_fvgs[i].bottom)*0.5;
         double dist=MathAbs(price-midF);
         if(dist > (atr_val>0?atr_val*6:1000*_Point)) continue; // tighter P2.10: 6 ATR
         double hF=MathAbs(g_fvgs[i].top-g_fvgs[i].bottom);
         double score=dist + hF*0.3; // closer + tighter preferred
         if(score<bestFvgScore){ bestFvgScore=score; bestFVG=i; }
      }
      if(bestFVG>=0){ zone_top=g_fvgs[bestFVG].top; zone_bottom=g_fvgs[bestFVG].bottom; found=true; }
      if(!found)
      {
         int bestZ=-1; double bestZScore=DBL_MAX;
         for(int i=0;i<ArraySize(g_zones);i++)
         {
            if(g_zones[i].bullish!=is_buy) continue;
            if(g_zones[i].state=="MITIGATED") continue;
            double midZ=(g_zones[i].top+g_zones[i].bottom)*0.5;
            double dist=MathAbs(price-midZ);
            if(dist > (atr_val>0?atr_val*6:1000*_Point)) continue;
            double hZ=MathAbs(g_zones[i].top-g_zones[i].bottom);
            // prefer discount/premium aligned + OTE
            double pdBonus=0;
            if(g_range.valid)
            {
               bool inDiscount = is_buy ? (midZ<=g_range.eq) : (midZ>=g_range.eq);
               if(!inDiscount) pdBonus+= atr_val*0.5;
            }
            double score=dist + hZ*0.2 + pdBonus;
            if(score<bestZScore){ bestZScore=score; bestZ=i; }
         }
         if(bestZ>=0){ zone_top=g_zones[bestZ].top; zone_bottom=g_zones[bestZ].bottom; found=true; }
      }
      if(!found)
      {
         // P2.10 synthetic: place in discount/premium, not centered on price, with quality height
         double a2=(atr_val>0? atr_val : 100*_Point);
         // bias synthetic toward discount for buys
         double height = MathMax(a2*0.65, 6*PipSize());
         if(g_range.valid)
         {
            if(is_buy)
            {
               // discount zone center
               double discMid = (g_range.low+g_range.eq)*0.5;
               if(price < g_range.eq) { zone_top=price + height*0.5; zone_bottom=price - height*0.5; }
               else { zone_top=discMid + height*0.5; zone_bottom=discMid - height*0.5; if(zone_top>price) {zone_top=price+height*0.4; zone_bottom=price-height*0.6;} }
            }
            else
            {
               double premMid = (g_range.high+g_range.eq)*0.5;
               if(price > g_range.eq) { zone_top=price + height*0.5; zone_bottom=price - height*0.5; }
               else { zone_top=premMid + height*0.5; zone_bottom=premMid - height*0.5; if(zone_bottom<price){zone_top=price+height*0.6; zone_bottom=price-height*0.4;} }
            }
         }
         else
         {
            if(is_buy){ zone_top=price + height*0.45; zone_bottom=price - height*0.55; }
            else      { zone_top=price + height*0.55; zone_bottom=price - height*0.45; }
         }
      }
      if((zone_top-zone_bottom) < min_zone_h)
      {
         double mid=(zone_top+zone_bottom)*0.5;
         zone_top=mid+min_zone_h*0.5;
         zone_bottom=mid-min_zone_h*0.5;
      }
      entry_price=(zone_top+zone_bottom)*0.5;
      double struct_price=last_str.price;
      sl_price=is_buy? struct_price - buf : struct_price + buf;
      if(is_buy && sl_price>=entry_price) sl_price=entry_price - (atr_val>0?atr_val:100*_Point);
      if(!is_buy && sl_price<=entry_price) sl_price=entry_price + (atr_val>0?atr_val:100*_Point);
      // ensure SL outside zone
      if(is_buy && sl_price>=zone_bottom) sl_price=zone_bottom - buf;
      if(!is_buy && sl_price<=zone_top) sl_price=zone_top + buf;
   }
   double minD=(atr_val>0)?atr_val*0.8:0.0;
   string ty1="",ty2="",ty3="";
   double t1=GreedyFindBestTarget(entry_price,is_buy,minD,ty1);
   if(t1==0){t1=entry_price+(is_buy?1:-1)*atr_val*1.5; ty1="ATR x1.5";}
   double t2=GreedyFindBestTarget(t1,is_buy,minD*0.5,ty2);
   if(t2==0){t2=entry_price+(is_buy?1:-1)*atr_val*2.5; ty2="ATR x2.5";}
   double t3=GreedyFindBestTarget(t2,is_buy,minD*0.5,ty3);
   if(t3==0){t3=entry_price+(is_buy?1:-1)*atr_val*4.0; ty3="ATR x4.0";}
   double risk_pips_calc=0;
   string risk_lvl_calc=CalculateRiskLevel(entry_price,sl_price,atr_val,g_spread,risk_pips_calc);
   double R=MathMax(MathAbs(entry_price-sl_price),_Point);
   double rr1_calc=MathAbs(t1-entry_price)/R;
   double rr2_calc=MathAbs(t2-entry_price)/R;
   double rr3_calc=MathAbs(t3-entry_price)/R;

   if(!InpUseRetestLifecycle)
   {
      //--- legacy behavior: fire immediately, no retest wait
      //    (engine now runs once per closed bar, so the counter no longer inflates per tick)
      g_trade_setup.valid=true;
      g_trade_setup.is_buy=is_buy;
      g_signal_count++;
      g_trade_setup.entry=entry_price; g_trade_setup.sl=sl_price;
      g_trade_setup.tp1=t1; g_trade_setup.tp1_type=ty1;
      g_trade_setup.tp2=t2; g_trade_setup.tp2_type=ty2;
      g_trade_setup.tp3=t3; g_trade_setup.tp3_type=ty3;
      g_trade_setup.risk_level=risk_lvl_calc; g_trade_setup.risk_pips=risk_pips_calc;
      g_trade_setup.rr1=rr1_calc; g_trade_setup.rr2=rr2_calc; g_trade_setup.rr3=rr3_calc;
      return;
   }

   //--- v5.3.0: seed/refresh the tracked setup with STABLE ID + blacklist
   string cand_id = GenerateSetupId(is_buy, last_str.time, zone_top, zone_bottom);

   //--- v5.7.0 (R2) SETUP STATE MACHINE PROTECTION -----------------------------
   // The candidate id embeds the zone. The zone depends on which OB ranks best at
   // the current price and, for the synthetic fallback, on price itself - so the
   // id can differ from the tracked one even when the IDEA is the same structure.
   // Previously any id mismatch replaced g_active_setup, killing READY/RETEST/
   // CONFIRMED setups on the next evaluation. Rules now:
   //   * CONFIRMED  -> never replaced here (only SL/TP3/invalidation retire it)
   //   * same structure anchor + same direction -> keep original zone (no repaint)
   //   * a NEW structure event -> supersede the old READY/RETEST idea
   if(g_active_setup.active)
   {
      if(g_active_setup.state=="CONFIRMED")
      {
         g_active_setup.ob_index_cache = FindOBIndexByUID(g_active_setup.ob_uid);
         DebugPrint(">>> Active CONFIRMED setup kept: "+g_active_setup.id);
         return;
      }
      if(g_active_setup.id==cand_id ||
         (g_active_setup.structure_time==last_str.time && g_active_setup.is_buy==is_buy))
      {
         g_active_setup.ob_index_cache = FindOBIndexByUID(g_active_setup.ob_uid);
         DebugPrint(">>> Same idea still tracked ("+g_active_setup.state+"), zone frozen: "+g_active_setup.id);
         return;
      }
      LogLifecycle("SUPERSEDED by new structure: "+g_active_setup.id+" -> "+cand_id);
      DebugPrint(">>> Setup superseded by new structure event: "+cand_id);
      g_active_setup.active=false;
   }

   if(IsBlacklisted(cand_id) || IsSameIdeaAsBlacklisted(is_buy, zone_top, zone_bottom))
   {
      AddBlocker("Idea blacklisted (recently invalidated/closed)");
      if(InpLogSignalDetails || DebugMode) Print(">>> SETUP BLACKLISTED (exact/fuzzy), skip: ",cand_id);
      LogLifecycle("Blocked re-create same idea: "+cand_id);
      return;
   }
   if(!g_active_setup.active || g_active_setup.id!=cand_id)
   {
      g_active_setup.active=true;
      g_active_setup.id=cand_id;
      g_active_setup.state="READY";
      g_active_setup.is_buy=is_buy;
      g_active_setup.created_bar=closed_bar;
      g_active_setup.created_time=g_buf_t[closed_bar+1];
      g_active_setup.structure_time=last_str.time;
      g_active_setup.zone_top=zone_top;
      g_active_setup.zone_bottom=zone_bottom;
      g_active_setup.ob_uid=(ob_idx>=0? g_order_blocks[ob_idx].id : "");
      g_active_setup.ob_index_cache=ob_idx;
      g_active_setup.quality_grade=g_trade_setup.quality_grade;
      g_active_setup.institutional_grade=g_trade_setup.institutional_grade;
      g_active_setup.confidence=g_trade_setup.confidence;
      g_active_setup.evidence_score=g_trade_setup.evidence_score;
      g_active_setup.entry=entry_price;
      g_active_setup.sl=sl_price;
      g_active_setup.tp1=t1; g_active_setup.tp1_type=ty1;
      g_active_setup.tp2=t2; g_active_setup.tp2_type=ty2;
      g_active_setup.tp3=t3; g_active_setup.tp3_type=ty3;
      g_active_setup.rr1=rr1_calc; g_active_setup.rr2=rr2_calc; g_active_setup.rr3=rr3_calc;
      g_active_setup.risk_level=risk_lvl_calc; g_active_setup.risk_pips=risk_pips_calc;
      g_active_setup.confirmed_bar=-1;
      g_active_setup.confirmed_time=0;
      g_active_setup.alert_fired=false;
      if(InpLogSignalDetails || DebugMode)
         Print(StringFormat(">>> SETUP READY: %s id=%s zone %s-%s entry %s sl %s tp1 %s tp2 %s tp3 %s (wait for retest)",
               is_buy?"BUY":"SELL",cand_id,DoubleToString(zone_bottom,_Digits),DoubleToString(zone_top,_Digits),
               DoubleToString(entry_price,_Digits),DoubleToString(sl_price,_Digits),
               DoubleToString(t1,_Digits),DoubleToString(t2,_Digits),DoubleToString(t3,_Digits)));
      LogLifecycle("NONE->READY "+cand_id);
   }
}

//--------------------------------------------------------------------
// v5.7.1 LIFECYCLE - READY -> RETEST -> CONFIRMED / INVALID, closed bars only
//--------------------------------------------------------------------
void ManageSetupLifecycle(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[],const bool is_new_bar)
{
   // LEGACY RETRO-COMPATIBILITY: do NOT touch g_trade_setup at all
   if(!InpUseRetestLifecycle) return;
   // Ticks may update drawings, never the frozen closed-bar lifecycle.
   if(!is_new_bar) return;
   // only from here we own g_trade_setup.valid
   g_trade_setup.valid=false;

   if(!g_active_setup.active) return;
   // resolve current OB index via stable UID each tick
   if(g_active_setup.ob_uid!="")
      g_active_setup.ob_index_cache = FindOBIndexByUID(g_active_setup.ob_uid);

   // P0.1 guard
   if(total<3) return;
   bool is_buy=g_active_setup.is_buy;
   int closed = total-2; // last closed bar
   int live   = total-1; // forming bar
   if(closed<0 || closed>=total || live<0 || live>=total) return;
   // Never retrospectively retest/confirm/invalidate a setup on its seed candle.
   if(closed<=g_active_setup.created_bar || t[closed]<g_active_setup.created_time) return;
   //--- P0.2 invalidation on CLOSED bar only + timeout/distance
   bool invalidated=false;
   // OB mitigated on closed bar
   if(g_active_setup.ob_uid!="" && g_active_setup.ob_index_cache>=0 && g_active_setup.ob_index_cache<ArraySize(g_order_blocks))
      if(g_order_blocks[g_active_setup.ob_index_cache].state=="MITIGATED") invalidated=true;

   double inv_buf=(g_atr>0)?g_atr*InpInvalidateBufferATR:0.0;
   // close hard through zone on closed bar
   if(is_buy && c[closed] < g_active_setup.zone_bottom - inv_buf) invalidated=true;
   if(!is_buy && c[closed] > g_active_setup.zone_top + inv_buf) invalidated=true;

   // P0.2 timeout + distance-based invalidation (P0.1 safe: check total and g_atr)
   if(!invalidated && (g_active_setup.state=="READY" || g_active_setup.state=="RETEST"))
   {
      int elapsed=-1;
      if(g_active_setup.created_bar>=0)
         elapsed = (total-1) - g_active_setup.created_bar;
      else
         elapsed = (int)((t[total-1] - g_active_setup.created_time)/PeriodSeconds());
      if(elapsed<0) elapsed=-elapsed;
      if(InpRetestTimeoutBars>0 && elapsed>InpRetestTimeoutBars)
      {
         invalidated=true;
         LogLifecycle(StringFormat("RETEST timeout %d > %d bars - invalidating %s",elapsed, InpRetestTimeoutBars, g_active_setup.id));
      }
      if(!invalidated && InpRetestMaxDistanceATR>0 && g_atr>0)
      {
         double zoneMid=(g_active_setup.zone_top+g_active_setup.zone_bottom)*0.5;
         double dist=MathAbs(c[closed]-zoneMid);
         double thr=g_atr*InpRetestMaxDistanceATR;
         if(dist>thr && elapsed > InpRetestTimeoutBars/2)
         {
            invalidated=true;
            LogLifecycle(StringFormat("Distance invalidation %.2f ATR (dist %.5f > %.5f) - %s", dist/g_atr, dist, thr, g_active_setup.id));
         }
      }
      if(!invalidated && IsSameIdeaAsBlacklisted(is_buy, g_active_setup.zone_top, g_active_setup.zone_bottom))
      {
         invalidated=true;
         LogLifecycle("Same idea as blacklisted - invalidating "+g_active_setup.id);
      }
   }

   if(invalidated)
   {
      if((InpLogSignalDetails || DebugMode) && g_active_setup.state!="INVALID")
         Print(">>> SETUP INVALIDATED (",g_active_setup.state,") - OB mitigated or price closed through zone/timeout/distance on bar ",closed," id=",g_active_setup.id);
      LogLifecycle("INVALID -> "+g_active_setup.state+" id="+g_active_setup.id);
      BlacklistSetup(g_active_setup.id, t[closed]);
      g_active_setup.state="INVALID";
      g_active_setup.active=false;
      return;
   }

   // RETEST requires a closed bar after setup availability.
   bool touched_live = false; // speculative UI must not become historical evidence
   bool touched_closed = (l[closed] <= g_active_setup.zone_top && h[closed] >= g_active_setup.zone_bottom);
   bool touched = touched_live || touched_closed;

   if(g_active_setup.state=="READY" && touched)
   {
      g_active_setup.state="RETEST";
      LogLifecycle("READY->RETEST "+g_active_setup.id+" touched live="+ (touched_live?"1":"0")+" closed="+(touched_closed?"1":"0"));
      if(InpLogSignalDetails) Print(">>> SETUP RETEST: price entered zone (live=",touched_live," closed=",touched_closed,") waiting for closed confirmation");
   }

   if(g_active_setup.state=="RETEST")
   {
      // CONFIRMED requires closed candle inside zone that closed back in trade direction (P0.1 guarded: closed validated)
      bool inside_closed = (l[closed] <= g_active_setup.zone_top && h[closed] >= g_active_setup.zone_bottom) ||
                           (c[closed] <= g_active_setup.zone_top && c[closed] >= g_active_setup.zone_bottom);
      bool bullish_close=c[closed]>o[closed];
      bool bearish_close=c[closed]<o[closed];
      bool confirmed = inside_closed && ((is_buy && bullish_close) || (!is_buy && bearish_close));
      if(confirmed)
      {
         g_active_setup.state="CONFIRMED";
         g_active_setup.confirmed_bar=closed;
         g_active_setup.confirmed_time=t[closed+1]; // availability, not candle open
         g_signal_count++;
         LogLifecycle("RETEST->CONFIRMED "+g_active_setup.id+" @ "+DoubleToString(g_active_setup.entry,_Digits));
         // v5.7.0 (R11): immutable historical marker on the confirming CLOSED bar
         DrawPersistentSignal(is_buy,t[closed+1],g_active_setup.entry,g_active_setup.quality_grade);
         if(InpLogSignalDetails || DebugMode)
            Print(StringFormat(">>> %s SIGNAL CONFIRMED | Entry %s | SL %s | TP1 %s | TP2 %s | TP3 %s | Bar %d %s | Grade %s Score:%d/100 Evidence:%d/100 | id=%s",
                  is_buy?"BUY":"SELL",
                  DoubleToString(g_active_setup.entry,_Digits),DoubleToString(g_active_setup.sl,_Digits),
                  DoubleToString(g_active_setup.tp1,_Digits),DoubleToString(g_active_setup.tp2,_Digits),DoubleToString(g_active_setup.tp3,_Digits),
                  closed,TimeToString(t[closed],TIME_DATE|TIME_MINUTES),
                  g_active_setup.quality_grade,g_active_setup.confidence,g_active_setup.evidence_score,g_active_setup.id));
      }
      else if(DebugMode)
      {
         Print(StringFormat("[Lifecycle] RETEST pending %s: inside_closed=%s close_dir=%s (bar %d) id=%s",
               is_buy?"BUY":"SELL",PF(inside_closed),PF(is_buy?bullish_close:bearish_close),closed,g_active_setup.id));
      }
   }

   if(g_active_setup.state=="CONFIRMED")
   {
      g_trade_setup.valid=true;
      g_trade_setup.is_buy=g_active_setup.is_buy;
      g_trade_setup.quality_grade=g_active_setup.quality_grade;
      g_trade_setup.institutional_grade=g_active_setup.institutional_grade;
      g_trade_setup.confidence=g_active_setup.confidence;
      g_trade_setup.evidence_score=g_active_setup.evidence_score;
      g_trade_setup.entry=g_active_setup.entry;
      g_trade_setup.sl=g_active_setup.sl;
      g_trade_setup.tp1=g_active_setup.tp1; g_trade_setup.tp1_type=g_active_setup.tp1_type;
      g_trade_setup.tp2=g_active_setup.tp2; g_trade_setup.tp2_type=g_active_setup.tp2_type;
      g_trade_setup.tp3=g_active_setup.tp3; g_trade_setup.tp3_type=g_active_setup.tp3_type;
      g_trade_setup.rr1=g_active_setup.rr1; g_trade_setup.rr2=g_active_setup.rr2; g_trade_setup.rr3=g_active_setup.rr3;
      g_trade_setup.risk_level=g_active_setup.risk_level;
      g_trade_setup.risk_pips=g_active_setup.risk_pips;
      g_trade_setup.ob_uid=g_active_setup.ob_uid;
      g_trade_setup.ob_index=g_active_setup.ob_index_cache;

      // retirement on CLOSED bar beyond SL/TP3
      bool sl_hit = is_buy ? (l[closed] <= g_active_setup.sl) : (h[closed] >= g_active_setup.sl);
      bool tp3_hit = is_buy ? (h[closed] >= g_active_setup.tp3) : (l[closed] <= g_active_setup.tp3);
      // never retire on the confirming bar itself (its wick already qualified the retest)
      if(closed>g_active_setup.confirmed_bar && (sl_hit || tp3_hit))
      {
         if(InpLogSignalDetails || DebugMode) Print(">>> SETUP CLOSED (",sl_hit?"SL":"TP3"," hit on closed bar ",closed,") - blacklisting ",g_active_setup.id);
         LogLifecycle(StringFormat("CONFIRMED->CLOSED(%s) %s",sl_hit?"SL":"TP3",g_active_setup.id));
         BlacklistSetup(g_active_setup.id, t[closed]);
         g_active_setup.active=false;
         g_trade_setup.valid=false; // retirement must not advertise a stale valid setup
      }
   }
}
void FireSetupAlert(const datetime bar_time)
{
   if(!InpAlertOnSetup) return;

   //--- lifecycle mode optional READY alert (once per stable setup id)
   if(InpUseRetestLifecycle && InpAlertOnSetupReady && g_active_setup.active &&
      g_active_setup.state=="READY" && !g_active_setup.alert_fired)
   {
      g_active_setup.alert_fired=true;
      string setup_msg=StringFormat("%s %s | SETUP forming, %s | wait for retest @ %s-%s",
         _Symbol,TFName((ENUM_TIMEFRAMES)_Period),
         g_active_setup.is_buy?"BUY":"SELL",
         DoubleToString(g_active_setup.zone_bottom,_Digits),
         DoubleToString(g_active_setup.zone_top,_Digits));
      Alert(setup_msg);
      if(InpShowDebugAlerts) Print("SETUP ALERT: ",setup_msg);
   }

   if(!g_trade_setup.valid) return;
   //--- v5.7.0 (R3): de-duplicate by SIGNAL IDENTITY, not by bar time.
   //    A CONFIRMED setup stays valid for many bars (until SL/TP3), and the old
   //    bar-time guard re-fired the same alert on every new bar.
   //    Identity = setup id + direction + confirmed bar time (lifecycle mode)
   //             = direction + bar time (legacy immediate mode: one per bar, as before)
   string sig_id;
   if(InpUseRetestLifecycle)
      sig_id=StringFormat("%s|%s|%I64d",g_active_setup.id,g_trade_setup.is_buy?"BUY":"SELL",(long)g_active_setup.confirmed_time);
   else
      sig_id=StringFormat("LEGACY|%s|%I64d",g_trade_setup.is_buy?"BUY":"SELL",(long)bar_time);
   if(sig_id==g_last_alert_id) return;
   g_last_alert_id=sig_id;
   g_last_alert_bar=bar_time;
   string msg=StringFormat("%s %s | %s %s CONFIRMED | Entry %s SL %s TP1 %s TP2 %s TP3 %s | Score:%d/100 Evidence:%d/100 | RR 1:%.1f/%.1f/%.1f | Risk:%s",
      _Symbol,TFName((ENUM_TIMEFRAMES)_Period),
      g_trade_setup.quality_grade,g_trade_setup.is_buy?"BUY":"SELL",
      DoubleToString(g_trade_setup.entry,_Digits),DoubleToString(g_trade_setup.sl,_Digits),
      DoubleToString(g_trade_setup.tp1,_Digits),DoubleToString(g_trade_setup.tp2,_Digits),DoubleToString(g_trade_setup.tp3,_Digits),
      g_trade_setup.confidence,g_trade_setup.evidence_score,
      g_trade_setup.rr1,g_trade_setup.rr2,g_trade_setup.rr3,g_trade_setup.risk_level);
   Alert(msg);
   if(InpShowDebugAlerts || DebugMode) Print("ALERT FIRED [",sig_id,"]: ",msg);
}

//====================================================================
// EMA / VWAP - incremental
//====================================================================
void FillEMAAndVWAP(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[],const long &tv[],const bool is_new_bar)
{
   //--- EMA: full copy once (or after a history change), then only the last 3 bars.
   //    v5.7.0 (R7): the old incremental call used start_pos=total-3, which in
   //    CopyBuffer() means "total-3 bars back from the present" = the OLDEST bars.
   if(!g_ema_filled || total!=ArraySize(BufEmaFast))
   {
      double fastBuf[],slowBuf[];
      ArraySetAsSeries(fastBuf,false); ArraySetAsSeries(slowBuf,false);
      ResetLastError();
      int nf=CopyBuffer(h_ema_fast,0,0,total,fastBuf);
      if(nf<total) DebugError("FillEMAAndVWAP","CopyBuffer EMA fast full copy short ("+IntegerToString(nf)+"/"+IntegerToString(total)+")",GetLastError());
      ResetLastError();
      int ns=CopyBuffer(h_ema_slow,0,0,total,slowBuf);
      if(ns<total) DebugError("FillEMAAndVWAP","CopyBuffer EMA slow full copy short ("+IntegerToString(ns)+"/"+IntegerToString(total)+")",GetLastError());
      for(int i=0;i<total;i++)
      {
         BufEmaFast[i]=(nf>0 && i<ArraySize(fastBuf))?fastBuf[i]:0.0;
         BufEmaSlow[i]=(ns>0 && i<ArraySize(slowBuf))?slowBuf[i]:0.0;
      }
      g_ema_filled=(nf==total && ns==total);
   }
   else
   {
      double fb[],sb[];
      ArraySetAsSeries(fb,false); ArraySetAsSeries(sb,false);
      int cnt=MathMin(3,total);
      if(CopyBuffer(h_ema_fast,0,0,cnt,fb)==cnt)
         for(int k=0;k<cnt;k++){ int i=total-cnt+k; if(i>=0 && i<total) BufEmaFast[i]=fb[k]; }
      if(CopyBuffer(h_ema_slow,0,0,cnt,sb)==cnt)
         for(int k=0;k<cnt;k++){ int i=total-cnt+k; if(i>=0 && i<total) BufEmaSlow[i]=sb[k]; }
   }

   //--- VWAP (session anchored at day start).
   //    v5.7.0 (R7): g_cum_pv/g_cum_v now hold CLOSED bars only. The live bar is
   //    evaluated as (cum + live) without mutating the sums, so ticks no longer
   //    add the same forming bar over and over, and a new bar just folds the bar
   //    that has just closed into the sums.
   int live=total-1;
   if(g_vwap_closed_to<0 || g_vwap_closed_to>total-2)
   {
      g_cum_pv=0; g_cum_v=0; g_vwap_anchor=0; g_vwap_closed_to=-1;
   }
   for(int i=g_vwap_closed_to+1;i<=total-2;i++)
   {
      datetime anchor=DayAnchor(t[i]);
      if(anchor!=g_vwap_anchor)
      {
         g_cum_pv=0; g_cum_v=0; g_vwap_anchor=anchor;
      }
      double typical=(h[i]+l[i]+c[i])/3.0;
      double v=(double)tv[i];
      g_cum_pv+=typical*v; g_cum_v+=v;
      BufVWAP[i]=(g_cum_v>0)?g_cum_pv/g_cum_v:typical;
   }
   g_vwap_closed_to=total-2;
   // Forming candle is presentation only, without changing closed sums.
   double typical=(h[live]+l[live]+c[live])/3.0;
   double v=(double)tv[live];
   bool same_day=(DayAnchor(t[live])==g_vwap_anchor);
   double pv=(same_day?g_cum_pv:0.0)+typical*v;
   double vv=(same_day?g_cum_v:0.0)+v;
   BufVWAP[live]=(vv>0)?pv/vv:typical;
}
datetime DayAnchor(const datetime t)
{
   MqlDateTime s; TimeToStruct(t,s);
   s.hour=0; s.min=0; s.sec=0;
   return StructToTime(s);
}

//====================================================================
// DETECTION - all confirm on CLOSED bars
//====================================================================
void DetectStructure(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[],const int scan_from=-1)
{
   //--- v5.7.0 (R4) CAUSAL STATE MACHINE -------------------------------------
   // * A fractal at bar f (N bars each side) only becomes KNOWN at bar f+N.
   //   The old full scan assigned last_high/last_low at bar f itself, i.e. it
   //   used N future bars (look-ahead) and could therefore disagree with what
   //   the same code produced live -> historical labels differed from live ones.
   // * The old incremental call restarted with trend=0 and an empty swing
   //   memory on a 12-bar tail, so breaks of older swings were missed and
   //   MSS/CHoCH/BOS were mislabelled. State now persists across calls:
   //   scan_from<0  -> full reset & full scan (rebuild path)
   //   scan_from>=0 -> continue exactly from the first unprocessed closed bar.
   double atr[]; ArraySetAsSeries(atr,false);
   ResetLastError();
   if(CopyBuffer(h_atr,0,0,total,atr)!=total){ g_data_ready=false; DebugError("DetectStructure","CopyBuffer ATR failed",GetLastError()); return; }
   int n=MathMax(1,InpSwingFractalN);
   int lastClosed=total-2;
   int minStart=MathMax(2*n,2);     // bar j evaluates fractal at j-n (needs j-2n>=0) and uses c[j-2]
   if(lastClosed<minStart) return;

   int start_j;
   if(scan_from<0 || g_str_scanned_to<0)
   {
      g_str_last_high=0.0; g_str_last_low=0.0; g_str_trend=0; g_str_displacement=false;
      g_str_high_origin=-1; g_str_low_origin=-1;
      start_j=minStart;
   }
   else
   {
      start_j=MathMax(minStart,g_str_scanned_to+1);
      if(start_j>lastClosed) return;   // nothing new
   }
   double last_high=g_str_last_high, last_low=g_str_last_low;
   int  trend=g_str_trend;
   bool displacement=g_str_displacement;

   for(int j=start_j;j<=lastClosed;j++)
   {
      // the swing that becomes confirmable on THIS closed bar
      if(atr[j]<=0 || atr[j]==EMPTY_VALUE) continue;
      int f=j-n;
      if(f>=n)
      {
         if(IsFractalHigh(h,f,n,total)){ last_high=h[f]; g_str_high_origin=f; }
         if(IsFractalLow(l,f,n,total)){ last_low=l[f]; g_str_low_origin=f; }
      }
      int i=j; // break candidate bar (closed)
      // A previous break's displacement is not evidence for this event.
      displacement=false;
      if(last_high>0 && c[i]>last_high)
      {
         // P1.8 dedup for incremental: skip if structure at same bar already exists
         bool dup=false;
         for(int _k=0;_k<ArraySize(g_structures);_k++) if(g_structures[_k].bar==i && MathAbs(g_structures[_k].price-last_high)<_Point*2) {dup=true; break;}
         if(dup){ trend=1; last_high=0; continue; }
         // Reject an unavailable swing parent or non-monotonic bar clock.
         if(g_str_high_origin<0 || g_str_high_origin+n+1>i ||
            t[g_str_high_origin+n+1]>t[i] || t[i+1]<=t[i])
         {
            DebugError("DetectStructure","Rejected causal chronology violation",0);
            last_high=0; continue;
         }
         string bt=""; int st=3;
         double move=c[i]-MathMax(c[i-1],c[i-2]);
         if(i<ArraySize(atr) && atr[i]>0 && move>=atr[i]*InpDisplacementATR){displacement=true; st=5;}
         if(trend<0 && displacement){bt="MSS"; st=5; displacement=false;}
         else if(trend<=0){bt="CHoCH"; st=4;}
         else {bt="BOS"; st=3;}
         int ob_bar=FindLastBearishOB(o,c,i,InpOBLookback);
         int idx=ArraySize(g_structures); ArrayResize(g_structures,idx+1,32);
         g_structures[idx].bar=i; g_structures[idx].time=t[i];
         g_structures[idx].price=last_high; g_structures[idx].bullish=true;
         g_structures[idx].confirmation_time=t[i+1];
         g_structures[idx].availability_time=t[i+1];
         g_structures[idx].swing_origin=g_str_high_origin;
         g_structures[idx].swing_confirmation_bar=g_str_high_origin+n;
         g_structures[idx].swing_availability_time=t[g_str_high_origin+n+1];
         g_structures[idx].displacement_atr=(atr[i]>0 && atr[i]!=EMPTY_VALUE)?move/atr[i]:0.0;
         g_structures[idx].type=bt; g_structures[idx].ob_bar=ob_bar;
         g_structures[idx].strength=st; g_structures[idx].priority=st;
         DebugPrint(StringFormat("[Structure] %s+ on closed bar %d %s broke %s (move %.1f ATR)",bt,i,TimeToString(t[i],TIME_DATE|TIME_MINUTES),DoubleToString(last_high,_Digits),(i<ArraySize(atr)&&atr[i]>0)?move/atr[i]:0.0));
         trend=1; last_high=0;
      }
      else if(last_low>0 && c[i]<last_low)
      {
         bool dup2=false;
         for(int _k=0;_k<ArraySize(g_structures);_k++) if(g_structures[_k].bar==i && MathAbs(g_structures[_k].price-last_low)<_Point*2) {dup2=true; break;}
         if(dup2){ trend=-1; last_low=0; continue; }
         // Reject an unavailable swing parent or non-monotonic bar clock.
         if(g_str_low_origin<0 || g_str_low_origin+n+1>i ||
            t[g_str_low_origin+n+1]>t[i] || t[i+1]<=t[i])
         {
            DebugError("DetectStructure","Rejected causal chronology violation",0);
            last_low=0; continue;
         }
         string bt=""; int st=3;
         double move=MathMin(c[i-1],c[i-2])-c[i];
         if(i<ArraySize(atr) && atr[i]>0 && move>=atr[i]*InpDisplacementATR){displacement=true; st=5;}
         if(trend>0 && displacement){bt="MSS"; st=5; displacement=false;}
         else if(trend>=0){bt="CHoCH"; st=4;}
         else {bt="BOS"; st=3;}
         int ob_bar=FindLastBullishOB(o,c,i,InpOBLookback);
         int idx=ArraySize(g_structures); ArrayResize(g_structures,idx+1,32);
         g_structures[idx].bar=i; g_structures[idx].time=t[i];
         g_structures[idx].price=last_low; g_structures[idx].bullish=false;
         g_structures[idx].confirmation_time=t[i+1];
         g_structures[idx].availability_time=t[i+1];
         g_structures[idx].swing_origin=g_str_low_origin;
         g_structures[idx].swing_confirmation_bar=g_str_low_origin+n;
         g_structures[idx].swing_availability_time=t[g_str_low_origin+n+1];
         g_structures[idx].displacement_atr=(atr[i]>0 && atr[i]!=EMPTY_VALUE)?move/atr[i]:0.0;
         g_structures[idx].type=bt; g_structures[idx].ob_bar=ob_bar;
         g_structures[idx].strength=st; g_structures[idx].priority=st;
         DebugPrint(StringFormat("[Structure] %s- on closed bar %d %s broke %s (move %.1f ATR)",bt,i,TimeToString(t[i],TIME_DATE|TIME_MINUTES),DoubleToString(last_low,_Digits),(i<ArraySize(atr)&&atr[i]>0)?move/atr[i]:0.0));
         trend=-1; last_low=0;
      }
   }
   // persist state for the next incremental continuation
   g_str_last_high=last_high; g_str_last_low=last_low;
   g_str_trend=trend; g_str_displacement=displacement;
   g_str_scanned_to=lastClosed;
}
bool IsFractalHigh(const double &h[],const int i,const int n,const int total)
{
   int lastClosed = total-2;
   // fractal must be fully confirmed on closed bar: need n bars left and right that are <= closed
   if(i-n<0 || i+n>lastClosed) return false;
   for(int k=i-n;k<=i+n;k++) if(k!=i && h[k]>=h[i]) return false;
   return true;
}
bool IsFractalLow(const double &l[],const int i,const int n,const int total)
{
   int lastClosed = total-2;
   if(i-n<0 || i+n>lastClosed) return false;
   for(int k=i-n;k<=i+n;k++) if(k!=i && l[k]<=l[i]) return false;
   return true;
}
int FindLastBearishOB(const double &o[],const double &c[],const int from,const int lookback)
{
   for(int i=from-1;i>=MathMax(0,from-lookback);i--) if(c[i]<o[i]) return i;
   return -1;
}
int FindLastBullishOB(const double &o[],const double &c[],const int from,const int lookback)
{
   for(int i=from-1;i>=MathMax(0,from-lookback);i--) if(c[i]>o[i]) return i;
   return -1;
}
void DetectOrderBlocks(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[])
{
   if(total<3) return;
   double atr[]; ArraySetAsSeries(atr,false);
   if(CopyBuffer(h_atr,0,0,total,atr)!=total){ g_data_ready=false; return; }
   int lastClosed = total-2;
   for(int i=0;i<ArraySize(g_structures);i++)
   {
      if(g_structures[i].ob_bar<0) continue;
      int ob_idx=g_structures[i].ob_bar;
      int available_bar=g_structures[i].bar;
      if(ob_idx<0 || ob_idx>=available_bar || available_bar>lastClosed) continue;
      double cur_atr=atr[available_bar];
      if(cur_atr<=0 || cur_atr==EMPTY_VALUE) continue;
      SOrderBlock ob;
      ob.bar=ob_idx;
      ob.time1=t[ob_idx];
      ob.time2=t[MathMin(total-1,ob_idx+100)];
      ob.bullish=g_structures[i].bullish;
      ob.mitigated=false;
      ob.strength=g_structures[i].strength;
      ob.state="ACTIVE";
      ob.distance_from_price=0;
      ob.age=total-1-ob_idx;
      ob.top=h[ob_idx];
      ob.bottom=l[ob_idx];
      if(cur_atr>0 && (ob.top-ob.bottom)>cur_atr*InpOBMaxHeightATR)
      {
         ob.top=MathMax(o[ob_idx],c[ob_idx]);
         ob.bottom=MathMin(o[ob_idx],c[ob_idx]);
         if((ob.top-ob.bottom)>cur_atr*InpOBMaxHeightATR) continue;
      }
      ob.id = GenerateOBId(t[ob_idx], ob.top, ob.bottom, ob.bullish);
      if(IsDuplicateOB(ob.top, ob.bottom, ob.bullish, cur_atr*0.2)) continue;

      bool touched=false;
      // mitigation check ONLY on closed bars
      for(int j=available_bar+1;j<=lastClosed;j++)
      {
         if(ob.bullish && l[j]<=ob.top && l[j]>=ob.bottom) touched=true;
         if(!ob.bullish && h[j]>=ob.bottom && h[j]<=ob.top) touched=true;
         if(ob.bullish && c[j]<ob.bottom)
         {
            ob.mitigated=true; ob.state="MITIGATED";
            AddBreakerBlock(h,l,c,t,j,ob.top,ob.bottom,false,total);
            break;
         }
         if(!ob.bullish && c[j]>ob.top)
         {
            ob.mitigated=true; ob.state="MITIGATED";
            AddBreakerBlock(h,l,c,t,j,ob.top,ob.bottom,true,total);
            break;
         }
      }
      if(!ob.mitigated && touched) ob.state="TOUCHED";
      // Live touches belong to rendering only; never mutate scored OB state.
      if(!ob.mitigated || !InpAutoRemoveMitigatedOB)
      {
         int idx=ArraySize(g_order_blocks); ArrayResize(g_order_blocks,idx+1,32); g_order_blocks[idx]=ob;
      }
   }
   if(InpAutoRemoveMitigatedOB && ArraySize(g_order_blocks)>InpMaxStrongOB*2)
   {
      // keep strongest per direction using strength index table, but rebuild filtered list preserving chronological order
      BuildOBStrengthIndex();
      SOrderBlock filtered[]; ArrayResize(filtered,0,16);
      for(int dir=0;dir<2;dir++)
      {
         bool want_bull=(dir==0);
         int kept=0;
         // iterate strength-sorted index
         for(int k=0;k<ArraySize(g_ob_strength_idx) && kept<InpMaxStrongOB;k++)
         {
            int idx=g_ob_strength_idx[k];
            if(idx>=ArraySize(g_order_blocks)) continue;
            if(g_order_blocks[idx].bullish!=want_bull) continue;
            if(g_order_blocks[idx].state=="MITIGATED") continue;
            int f=ArraySize(filtered); ArrayResize(filtered,f+1,16); filtered[f]=g_order_blocks[idx]; kept++;
         }
      }
      // restore chronological order (by bar)
      for(int i=1;i<ArraySize(filtered);i++)
      {
         SOrderBlock key=filtered[i]; int j=i-1;
         while(j>=0 && filtered[j].bar > key.bar){ filtered[j+1]=filtered[j]; j--; }
         filtered[j+1]=key;
      }
      ArrayResize(g_order_blocks,ArraySize(filtered),32);
      for(int i=0;i<ArraySize(filtered);i++) g_order_blocks[i]=filtered[i];
   }
}
void AddBreakerBlock(const double &h[],const double &l[],const double &c[],const datetime &t[],const int break_bar,const double top,const double bottom,const bool bullish,const int total)
{
   SBreaker br;
   br.bar=break_bar; br.time1=t[break_bar];
   br.time2=t[MathMin(total-1,break_bar+80)];
   br.top=top; br.bottom=bottom; br.bullish=bullish; br.state="ACTIVE";
   int lastClosed=total-2;
   bool cleared=false;
   for(int k=break_bar+1;k<=lastClosed;k++)
   {
      if(bullish){if(l[k]<=top && l[k]>=bottom) br.state="TOUCHED"; if(c[k]<bottom){cleared=true; break;}}
      else {if(h[k]>=bottom && h[k]<=top) br.state="TOUCHED"; if(c[k]>top){cleared=true; break;}}
   }
   if(cleared) return;
   // v5.7.0 (R5): DetectOrderBlocks re-evaluates mitigated OBs on every incremental
   // pass; without this guard the same breaker was appended once per bar.
   if(IsDuplicateBreaker(br.bar,br.top,br.bottom,br.bullish)) return;
   int idx=ArraySize(g_breakers); ArrayResize(g_breakers,idx+1,16); g_breakers[idx]=br;
}
void DetectZones(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[],const int scan_from=-1)
{
   if(total<3) return;
   double atr[]; ArraySetAsSeries(atr,false);
   if(CopyBuffer(h_atr,0,0,total,atr)!=total){ g_data_ready=false; return; }
   int from=MathMax(10,total-InpZoneLookback);
   if(scan_from>=0) from=MathMax(from, scan_from);
   int lastClosed=total-2;
   for(int i=from;i<=lastClosed;i++)
   {
      if(i>=ArraySize(atr) || atr[i]<=0) continue;
      double body=c[i]-o[i];
      bool bull_disp=(body>=atr[i]*InpDisplacementATR);
      bool bear_disp=(-body>=atr[i]*InpDisplacementATR);
      if(!bull_disp && !bear_disp) continue;
      int b_end=i-1; if(b_end<1) continue;
      int b_start=b_end;
      for(int j=i-1;j>=MathMax(1,i-4);j--)
      {
         double bb=MathAbs(c[j]-o[j]);
         double rng=h[j]-l[j];
         if(bb<=atr[i]*InpZoneBaseBodyATR && rng<=atr[i]*1.5) b_start=j;
         else break;
      }
      double zt=-DBL_MAX,zb=DBL_MAX;
      for(int j=b_start;j<=b_end;j++){if(h[j]>zt) zt=h[j]; if(l[j]<zb) zb=l[j];}
      if(zt<=zb) continue;
      double cur_atr=atr[i]; // historical acceptance uses this closed event only
      if(cur_atr>0 && (zt-zb)>cur_atr*InpZoneMaxHeightATR) continue;
      // v5.4.1: dedup by origin bar so tail rescans don't duplicate an
      // already-tracked zone (mirrors the structure dedup approach)
      bool dupZone=false;
      for(int _k=0;_k<ArraySize(g_zones);_k++) if(g_zones[_k].bar==i){ dupZone=true; break; }
      if(dupZone) continue;
      SZone zn;
      zn.bar=i; zn.time1=t[b_start]; zn.time2=t[MathMin(total-1,i+80)];
      zn.top=zt; zn.bottom=zb; zn.bullish=bull_disp;
      zn.state="ACTIVE"; zn.touches=0; zn.strength_score=0;
      for(int j=i+1;j<=lastClosed;j++)
      {
         if(zn.bullish){if(l[j]<=zn.top && l[j]>=zn.bottom){zn.touches++; zn.state="MITIGATION";} if(c[j]<zn.bottom){zn.state="MITIGATED"; break;}}
         else {if(h[j]>=zn.bottom && h[j]<=zn.top){zn.touches++; zn.state="MITIGATION";} if(c[j]>zn.top){zn.state="MITIGATED"; break;}}
      }
      if(zn.state=="MITIGATED") continue;
      int idx=ArraySize(g_zones); ArrayResize(g_zones,idx+1,16); g_zones[idx]=zn;
   }
   if(ArraySize(g_zones)>InpMaxZonesShown)
   {
      int base=ArraySize(g_zones)-InpMaxZonesShown;
      SZone kept[]; ArrayResize(kept,InpMaxZonesShown);
      for(int i=0;i<InpMaxZonesShown;i++) kept[i]=g_zones[base+i];
      ArrayResize(g_zones,InpMaxZonesShown,16);
      for(int i=0;i<InpMaxZonesShown;i++) g_zones[i]=kept[i];
   }
}
void DetectFVG(const int total,const double &o[],const double &h[],const double &l[],const double &c[],const datetime &t[],const int scan_from=-1)
{
   if(total<3) return;
   double atr[]; ArraySetAsSeries(atr,false);
   if(CopyBuffer(h_atr,0,0,total,atr)!=total){ g_data_ready=false; return; }
   int from=MathMax(2,total-InpFVGLookbackBars);
   if(scan_from>=0) from=MathMax(from, scan_from);
   int lastClosed=total-2;
   for(int i=from;i<=lastClosed;i++)
   {
      int A=i-2,C=i;
      if(l[C]>h[A])
      {
         double gap=l[C]-h[A];
         if(i<ArraySize(atr) && atr[i]>0 && gap>=atr[i]*InpFVGMinSizeATR)
         {
            SFVG fvg;
            fvg.bar=i; fvg.time1=t[A]; fvg.time2=t[MathMin(total-1,C+50)];
            fvg.top=l[C]; fvg.bottom=h[A];
            fvg.bullish=true; fvg.filled=false; fvg.state="OPEN";
            fvg.mid_price=(fvg.top+fvg.bottom)*0.5;
            for(int j=C+1;j<=lastClosed;j++)
            {
               if(l[j]<=fvg.bottom){fvg.filled=true; fvg.state="FILLED"; break;}
               else if(l[j]<fvg.top){double fp=(fvg.top-l[j])/(fvg.top-fvg.bottom)*100; if(fp>50) fvg.state="PARTIAL";}
            }
            if(!fvg.filled || !InpHideFilledFVG) AddOrMergeFVG(fvg, total, h, l);
         }
      }
      else if(h[C]<l[A])
      {
         double gap=l[A]-h[C];
         if(i<ArraySize(atr) && atr[i]>0 && gap>=atr[i]*InpFVGMinSizeATR)
         {
            SFVG fvg;
            fvg.bar=i; fvg.time1=t[A]; fvg.time2=t[MathMin(total-1,C+50)];
            fvg.top=l[A]; fvg.bottom=h[C];
            fvg.bullish=false; fvg.filled=false; fvg.state="OPEN";
            fvg.mid_price=(fvg.top+fvg.bottom)*0.5;
            for(int j=C+1;j<=lastClosed;j++)
            {
               if(h[j]>=fvg.top){fvg.filled=true; fvg.state="FILLED"; break;}
               else if(h[j]>fvg.bottom){double fp=(h[j]-fvg.bottom)/(fvg.top-fvg.bottom)*100; if(fp>50) fvg.state="PARTIAL";}
            }
            if(!fvg.filled || !InpHideFilledFVG) AddOrMergeFVG(fvg, total, h, l);
         }
      }
   }
}
void AddOrMergeFVG(SFVG &fvg, const int total, const double &h[], const double &l[])
{
   // Origin identity is immutable, independently of display/merge settings.
   // Merging evidence geometry retrospectively changes fill history. Keep the
   // legacy input for preset compatibility, but do not merge detector records.
   for(int i=0;i<ArraySize(g_fvgs);i++)
      if(g_fvgs[i].bar==fvg.bar && g_fvgs[i].bullish==fvg.bullish) return;
   int idx=ArraySize(g_fvgs); ArrayResize(g_fvgs,idx+1,16); g_fvgs[idx]=fvg;
}

void DetectLiquidity(const int total,const double &h[],const double &l[],const double &c[],const double &o[],const long &tv[],const datetime &t[],const int scan_from=-1)
{
   double tol=(InpLiqToleranceATR>0 && g_atr>0)? g_atr*InpLiqToleranceATR : InpLiquidityTolerancePips*PipSize();
   if(tol<=0) tol=5*PipSize();
   int from=MathMax(InpLiquidityFractalN*2,total-InpLiquidityLookback);
   if(scan_from>=0) from=MathMax(from, scan_from);
   int lastClosed=total-2;
   for(int i=from;i<=lastClosed;i++)
   {
      bool is_high=IsFractalHigh(h,i,InpLiquidityFractalN,total);
      bool is_low=IsFractalLow(l,i,InpLiquidityFractalN,total);
      if(!is_high && !is_low) continue;
      double level=is_high?h[i]:l[i];
      string ptype=is_high?"EQH":"EQL";
      if(IsDuplicateLiquidity(level, ptype, tol)) continue;
      for(int j=i+1;j<=lastClosed && j<MathMin(total-1,i+40);j++)
      {
         double cmp=is_high?h[j]:l[j];
         if(MathAbs(cmp-level)>tol) continue;
         SLiquidity liq;
         liq.bar=j; liq.time=t[j]; liq.price=level;
         liq.type=ptype;
         liq.swept=false; liq.priority=0;
         if(IsDuplicateLiquidity(level, ptype, tol)) break;
         int idx=ArraySize(g_liquidity); ArrayResize(g_liquidity,idx+1,16); g_liquidity[idx]=liq;
         // P2.9: check sweep with displacement/volume + stronger duplicate (tol*0.8)
         for(int k=j+1;k<=lastClosed && k<MathMin(total,j+15);k++)
         {
            bool sweepHigh = (is_high && h[k]>level+tol && c[k]<level);
            bool sweepLow  = (!is_high && l[k]<level-tol && c[k]>level);
            if(!sweepHigh && !sweepLow) continue;
            // P2.9 displacement/volume filter
            if(!SweepHasDisplacementOrVolume(k, is_high, level, g_atr, h, l, o, c, tv)) continue;
            // stronger duplicate: use tol*0.7 for swept
            double sweptTol=tol*0.7;
            if(sweepHigh)
            {
               if(IsDuplicateLiquidity(h[k],"BSL TAKEN",sweptTol)) break;
               SLiquidity sw; sw.bar=k; sw.time=t[k]; sw.price=h[k]; sw.type="BSL TAKEN"; sw.swept=true; sw.priority=0;
               idx=ArraySize(g_liquidity); ArrayResize(g_liquidity,idx+1,16); g_liquidity[idx]=sw; break;
            }
            else
            {
               if(IsDuplicateLiquidity(l[k],"SSL TAKEN",sweptTol)) break;
               SLiquidity sw; sw.bar=k; sw.time=t[k]; sw.price=l[k]; sw.type="SSL TAKEN"; sw.swept=true; sw.priority=0;
               idx=ArraySize(g_liquidity); ArrayResize(g_liquidity,idx+1,16); g_liquidity[idx]=sw; break;
            }
         }
         break;
      }
   }
}
void DetectDealingRange(const int total,const double &h[],const double &l[],const datetime &t[])
{
   if(total<3) return;
   g_range.valid=false;
   int from=MathMax(InpSwingRangeFractalN,total-InpSwingLookback);
   int scan_start=total-1-InpSwingRangeFractalN;
   if(scan_start<from) return;
   // scan only closed bars for range anchors
   int lastClosed=total-2;
   scan_start=MathMin(scan_start,lastClosed);
   int hb=-1,lb=-1; double hv=0.0,lv=0.0;
   for(int i=scan_start;i>=from;i--)
   {
      if(hb<0 && IsFractalHigh(h,i,InpSwingRangeFractalN,total)){hb=i; hv=h[i];}
      if(lb<0 && IsFractalLow(l,i,InpSwingRangeFractalN,total)){lb=i; lv=l[i];}
      if(hb>=0 && lb>=0) break;
   }
   if(hb<0 || lb<0 || hv<=lv) return;
   g_range.valid=true;
   g_range.bar_high=hb; g_range.bar_low=lb;
   g_range.time_high=t[hb]; g_range.time_low=t[lb];
   g_range.high=hv; g_range.low=lv;
   g_range.eq=(hv+lv)*0.5;
   g_range.bullish_leg=(lb<hb);
}
bool GetOTEZone(double &ote_top,double &ote_bottom,bool &ote_is_buy)
{
   if(!g_range.valid) return false;
   double rs=g_range.high-g_range.low;
   double fs=MathMin(InpOTEFibStart,InpOTEFibEnd);
   double fe=MathMax(InpOTEFibStart,InpOTEFibEnd);
   if(g_range.bullish_leg){ote_top=g_range.high-rs*fs; ote_bottom=g_range.high-rs*fe; ote_is_buy=true;}
   else {ote_bottom=g_range.low+rs*fs; ote_top=g_range.low+rs*fe; ote_is_buy=false;}
   return true;
}
void ComputeHTFBias()
{
   datetime ht=iTime(_Symbol,InpHTFBiasTF,0);
   datetime dt=iTime(_Symbol,PERIOD_D1,0);
   if(InpUseMemoization)
   {
      if(ht>0 && ht==g_htf_cache_time && dt==g_d1_cache_time){g_memo_hit=true; return;}
   }
   g_memo_hit=false; g_htf_bias=0;
   g_d1_high=0; g_d1_low=0; g_d1_close=0; g_htf_eq=0;
   int n=InpSwingLookback;
   //--- v5.7.0 (R6 / MTF audit): HTF context uses CLOSED HTF bars only (start=1),
   //    so the bias cannot flip intrabar and is identical after a refresh/restart.
   double hh[],hl[],hc[];
   ArraySetAsSeries(hh,false); ArraySetAsSeries(hl,false); ArraySetAsSeries(hc,false);
   ResetLastError();
   if(CopyHigh(_Symbol,InpHTFBiasTF,1,n,hh)<n)  { g_data_ready=false; DebugError("ComputeHTFBias","CopyHigh "+TFName(InpHTFBiasTF)+" failed/short",GetLastError()); return; }
   if(CopyLow(_Symbol,InpHTFBiasTF,1,n,hl)<n)   { g_data_ready=false; DebugError("ComputeHTFBias","CopyLow "+TFName(InpHTFBiasTF)+" failed/short",GetLastError()); return; }
   if(CopyClose(_Symbol,InpHTFBiasTF,1,1,hc)<1) { g_data_ready=false; DebugError("ComputeHTFBias","CopyClose "+TFName(InpHTFBiasTF)+" failed",GetLastError()); return; }
   int hi=0,lo=0;
   for(int i=0;i<n;i++){if(hh[i]>hh[hi]) hi=i; if(hl[i]<hl[lo]) lo=i;}
   double eq=(hh[hi]+hl[lo])*0.5; g_htf_eq=eq;
   int htf_bias=(hc[0]<eq)?1:-1;   // below equilibrium = discount = bullish bias (unchanged rule)
   // D1 macro context (closed daily bars)
   double dh[],dl[],dc[];
   ArraySetAsSeries(dh,false); ArraySetAsSeries(dl,false); ArraySetAsSeries(dc,false);
   if(CopyHigh(_Symbol,PERIOD_D1,1,n,dh)>=n && CopyLow(_Symbol,PERIOD_D1,1,n,dl)>=n && CopyClose(_Symbol,PERIOD_D1,1,1,dc)>=1)
   {
      int dhi=0,dlo=0;
      for(int i=0;i<n;i++){if(dh[i]>dh[dhi]) dhi=i; if(dl[i]<dl[dlo]) dlo=i;}
      double deq=(dh[dhi]+dl[dlo])*0.5;
      int d_bias=(dc[0]<deq)?1:-1;
      g_htf_bias=(d_bias==htf_bias)?d_bias:0;
      // cache PREVIOUS DAY levels. With a chronological (non-series) array the
      // most recent element is the LAST one; the old code took dh[0] = the day
      // n bars ago, so PDH/PDL/pivots/camarilla/TP magnets were wrong.
      if(dh[n-1]>0) { g_d1_high=dh[n-1]; g_d1_low=dl[n-1]; g_d1_close=dc[0]; }
   }
   else
   {
      g_data_ready=false;
      DebugError("ComputeHTFBias","D1 unavailable - no decision",GetLastError());
      return;
   }
   g_htf_cache_time=ht; g_d1_cache_time=dt; // commit successful cache only
   DebugPrint(StringFormat("[HTF] %s bias=%d | combined D1+%s bias=%s | eq=%s | PDH %s PDL %s",TFName(InpHTFBiasTF),htf_bias,TFName(InpHTFBiasTF),
              g_htf_bias==1?"BULL":(g_htf_bias==-1?"BEAR":"NEUTRAL"),DoubleToString(eq,_Digits),DoubleToString(g_d1_high,_Digits),DoubleToString(g_d1_low,_Digits)));
}
void DetectJudasSwing(const int total,const datetime &t[],const double &h[],const double &l[],const double &c[])
{
   g_judas=0; g_judas_bar=0;
   datetime today=DayAnchor(t[total-1]);
   datetime a_start=today+(datetime)(InpAsianStart*3600);
   datetime a_end=today+(datetime)(InpAsianEnd*3600);
   if(t[total-1]<a_end) return;
   double ah=-DBL_MAX,al=DBL_MAX; bool found=false;
   for(int i=total-1;i>=0;i--)
   {
      if(t[i]<a_start) break;
      if(t[i]<a_end){if(h[i]>ah) ah=h[i]; if(l[i]<al) al=l[i]; found=true;}
   }
   if(!found || ah<=al) return;
   int lastClosed=total-2;
   for(int i=lastClosed;i>=0;i--)
   {
      if(t[i]<a_end) break;
      if(l[i]<al && c[i]>al){g_judas=1; g_judas_bar=i; return;}
      if(h[i]>ah && c[i]<ah){g_judas=-1; g_judas_bar=i; return;}
   }
}
void DetectKillZones(const int total,const datetime &t[],const double &h[],const double &l[])
{
   datetime today=DayAnchor(t[total-1]);
   datetime ls=today+(datetime)(InpLondonStart*3600);
   datetime le=today+(datetime)((InpLondonStart+3)*3600);
   datetime nsx=today+(datetime)(InpNewYorkStart*3600);
   datetime ne=today+(datetime)((InpNewYorkStart+3)*3600);
   double lh=-DBL_MAX,ll=DBL_MAX,nh=-DBL_MAX,nl=DBL_MAX;
   bool fl=false,fn=false;
   for(int i=total-1;i>=0;i--)
   {
      if(t[i]>=ls && t[i]<=le){if(h[i]>lh) lh=h[i]; if(l[i]<ll) ll=l[i]; fl=true;}
      if(t[i]>=nsx && t[i]<=ne){if(h[i]>nh) nh=h[i]; if(l[i]<nl) nl=l[i]; fn=true;}
   }
   if(fl){int idx=ArraySize(g_kill_zones); ArrayResize(g_kill_zones,idx+1,16); g_kill_zones[idx].start=ls; g_kill_zones[idx].end=le; g_kill_zones[idx].high=lh; g_kill_zones[idx].low=ll; g_kill_zones[idx].name="London KZ"; g_kill_zones[idx].col=clrGold;}
   if(fn){int idx=ArraySize(g_kill_zones); ArrayResize(g_kill_zones,idx+1,16); g_kill_zones[idx].start=nsx; g_kill_zones[idx].end=ne; g_kill_zones[idx].high=nh; g_kill_zones[idx].low=nl; g_kill_zones[idx].name="NY KZ"; g_kill_zones[idx].col=clrDodgerBlue;}
}

//====================================================================
// DRAWING
//====================================================================
void DrawZones()
{
   for(int i=0;i<ArraySize(g_zones);i++)
   {
      color col=g_zones[i].bullish?InpColorDemand:InpColorSupply;
      string label=g_zones[i].bullish? ((g_zones[i].state=="MITIGATION")?"DEMAND - MIT":"DEMAND") : ((g_zones[i].state=="MITIGATION")?"SUPPLY - MIT":"SUPPLY");
      bool is_early = (InpRealTimeZones && InpShowEarlyZones && i >= ArraySize(g_zones)-2 && g_zones[i].bar >= g_rates_total-3);
      if(is_early) label += " *EARLY";
      string name=PFX+"ZN_"+IntegerToString(i);
      int transp = is_early ? InpEarlyZoneTransparency : InpOBTransparency;
      DrawZoneBox(name,g_zones[i].time1,g_zones[i].top,g_zones[i].time2,g_zones[i].bottom,col,label,transp);
      DrawTextLabel(name+"_L",g_zones[i].time1,g_zones[i].top,label,col,true,8);
   }
}
void DrawPremiumDiscount(const int total,const datetime &t[])
{
   if(!g_range.valid) return;
   int earliest=MathMin(g_range.bar_high,g_range.bar_low);
   int capped=MathMax(earliest,total-1-InpRangeBoxMaxBars);
   datetime t1=t[capped];
   datetime t2=t[total-1]+(datetime)(PeriodSeconds()*20);
   if(InpShowPremiumDiscount)
   {
      int tr=InpDeclutter?InpPDTransparency:92;
      DrawZoneBox(PFX+"PREM",t1,g_range.high,t2,g_range.eq,InpColorPremium,"PREMIUM",tr);
      DrawZoneBox(PFX+"DISC",t1,g_range.eq,t2,g_range.low,InpColorDiscount,"DISCOUNT",tr);
      DrawTextLabel(PFX+"PREM_L",t1,g_range.high,"PREMIUM",InpColorPremium,true,8);
      DrawTextLabel(PFX+"DISC_L",t1,g_range.low,"DISCOUNT",InpColorDiscount,false,8);
   }
   if(InpShowFibonacci)
   {
      double lv[]={0.0,0.236,0.382,0.5,0.618,0.705,0.79,1.0};
      double rs=g_range.high-g_range.low;
      for(int i=0;i<ArraySize(lv);i++)
      {
         if(InpDeclutter && MathAbs(lv[i]-0.5)>0.001 && MathAbs(lv[i]-0.618)>0.001 && MathAbs(lv[i]-0.705)>0.001 && MathAbs(lv[i]-0.79)>0.001) continue;
         double p=g_range.bullish_leg? g_range.low+rs*lv[i] : g_range.high-rs*lv[i];
         color col=(MathAbs(lv[i]-0.5)<0.0001)?InpColorEQ:InpColorFib;
         int style=(MathAbs(lv[i]-0.5)<0.0001)?STYLE_SOLID:STYLE_DOT;
         string nm=PFX+"FIB_"+IntegerToString(i);
         DrawFibLine(nm,t1,t2,p,col,style,1);
         if(!InpDeclutter) DrawTextLabel(nm+"_L",t1,p,StringFormat("%.1f%%",lv[i]*100),col,false,7);
      }
   }
   if(InpShowOTE)
   {
      double ot=0,ob=0; bool ib=false;
      if(GetOTEZone(ot,ob,ib))
      {
         string lbl="OTE "+(ib?"BUY":"SELL");
         DrawZoneBox(PFX+"OTE",t1,ot,t2,ob,InpColorOTE,lbl,InpDeclutter?92:82);
         DrawTextLabel(PFX+"OTE_L",t1,(ot+ob)*0.5,lbl,InpColorOTE,true,8);
      }
   }
}
void DrawBreakerZones()
{
   int start=MathMax(0,ArraySize(g_breakers)-InpMaxBreakersShown);
   for(int i=start;i<ArraySize(g_breakers);i++)
   {
      string label=g_breakers[i].bullish?"BREAKER UP":"BREAKER DN";
      if(g_breakers[i].state=="TOUCHED") label+=" (T)";
      string name=PFX+"BRK_"+IntegerToString(i);
      DrawZoneBox(name,g_breakers[i].time1,g_breakers[i].top,g_breakers[i].time2,g_breakers[i].bottom,InpColorBreaker,label,InpOBTransparency);
      DrawTextLabel(name+"_L",g_breakers[i].time1,g_breakers[i].top,label,InpColorBreaker,true,8);
   }
}
void DrawStructureAndOB()
{
   int start=MathMax(0,ArraySize(g_structures)-InpMaxStructureShown);
   for(int i=start;i<ArraySize(g_structures);i++)
   {
      color col; string arrow;
      if(g_structures[i].type=="BOS"){col=clrDodgerBlue; arrow=g_structures[i].bullish?"BOS+":"BOS-";}
      else if(g_structures[i].type=="CHoCH"){col=clrOrange; arrow=g_structures[i].bullish?"CHoCH+":"CHoCH-";}
      else {col=clrDeepPink; arrow=g_structures[i].bullish?"MSS+":"MSS-";}
      DrawTextLabel(PFX+"STR_"+IntegerToString(i),g_structures[i].time,g_structures[i].price,arrow,col,!g_structures[i].bullish,10);
   }
   // draw OBs chronological
   for(int i=0;i<ArraySize(g_order_blocks);i++)
   {
      bool is_entry=(g_order_blocks[i].id==g_trade_setup.ob_uid && g_trade_setup.valid) || (g_order_blocks[i].id==g_active_setup.ob_uid && g_active_setup.active);
      color col; string label;
      if(g_order_blocks[i].state=="MITIGATED"){col=clrDimGray; label="OB (Mit)";}
      else if(g_order_blocks[i].bullish){col=InpColorOB; label=(g_order_blocks[i].strength>=4)?"Strong OB+":"OB+";}
      else {col=InpColorOB_Bear; label=(g_order_blocks[i].strength>=4)?"Strong OB-":"OB-";}
      if(is_entry){col=clrAqua; label=">> ENTRY OB";}
      string name=PFX+"OB_"+IntegerToString(i)+"_"+IntegerToString(g_order_blocks[i].bar);
      DrawZoneBox(name,g_order_blocks[i].time1,g_order_blocks[i].top,g_order_blocks[i].time2,g_order_blocks[i].bottom,col,label,is_entry?76:InpOBTransparency);
      string stars=""; for(int s=0;s<g_order_blocks[i].strength;s++) stars+="*";
      DrawTextLabel(name+"S",g_order_blocks[i].time1,g_order_blocks[i].top,stars+(is_entry?" ENTRY":""),col,true,9);
   }
}
void DrawFVGZones()
{
   int start=MathMax(0,ArraySize(g_fvgs)-InpMaxFVGShown);
   for(int i=start;i<ArraySize(g_fvgs);i++)
   {
      color col=(g_fvgs[i].state=="FILLED")?clrDimGray:InpColorFVG;
      string name=PFX+"FVG"+IntegerToString(i);
      DrawZoneBox(name,g_fvgs[i].time1,g_fvgs[i].top,g_fvgs[i].time2,g_fvgs[i].bottom,col,"FVG",92);
      DrawTextLabel(name+"_S",g_fvgs[i].time1,g_fvgs[i].top,"FVG "+g_fvgs[i].state,col,true,7);
   }
}
void DrawLiquidityMarkers()
{
   // v5.4.1: removed the dead unused "i" alias from the original priority
   // branch (it computed g_liq_priority_idx[n-1-k] and never used it -
   // only idx=g_liq_priority_idx[k] was actually drawn).
   int n=ArraySize(g_liquidity);
   int start=0;
   if(n>InpMaxLiquidityShown*2) start=n-InpMaxLiquidityShown*2;
   if(ArraySize(g_liq_priority_idx)==n && n>0)
   {
      int cnt=MathMin(InpMaxLiquidityShown*2, n);
      for(int k=0;k<cnt;k++)
      {
         int idx=g_liq_priority_idx[k];
         if(idx>=n) continue;
         color col; bool above;
         if(g_liquidity[idx].type=="EQH"){col=clrOrange; above=true;}
         else if(g_liquidity[idx].type=="EQL"){col=clrDodgerBlue; above=false;}
         else if(StringFind(g_liquidity[idx].type,"BSL")>=0){col=clrRed; above=true;}
         else {col=clrLime; above=false;}
         DrawTextLabel(PFX+"LIQ_"+IntegerToString(idx),g_liquidity[idx].time,g_liquidity[idx].price,g_liquidity[idx].type,col,above,8);
      }
      return;
   }
   for(int i=start;i<n;i++)
   {
      color col; bool above;
      if(g_liquidity[i].type=="EQH"){col=clrOrange; above=true;}
      else if(g_liquidity[i].type=="EQL"){col=clrDodgerBlue; above=false;}
      else if(StringFind(g_liquidity[i].type,"BSL")>=0){col=clrRed; above=true;}
      else {col=clrLime; above=false;}
      DrawTextLabel(PFX+"LIQ_"+IntegerToString(i),g_liquidity[i].time,g_liquidity[i].price,g_liquidity[i].type,col,above,8);
   }
}
void DrawKillZones()
{
   for(int i=0;i<ArraySize(g_kill_zones);i++)
   {
      string name=PFX+"KZ_"+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         ObjectCreate(0,name,OBJ_RECTANGLE,0,g_kill_zones[i].start,g_kill_zones[i].high,g_kill_zones[i].end,g_kill_zones[i].low);
         ObjectSetInteger(0,name,OBJPROP_FILL,true);
         ObjectSetInteger(0,name,OBJPROP_BACK,true);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_COLOR,BlendColor(g_kill_zones[i].col,10));
      }
      DrawTextLabel(name+"_L",g_kill_zones[i].start,g_kill_zones[i].high,g_kill_zones[i].name,g_kill_zones[i].col,true,8);
   }
}
void DrawQuantumDashboard(const int total,const double &c[])
{
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string L[]; ArrayResize(L,200);
   int ln=0;
   L[ln++]="=======================";
   L[ln++]=" Quantum SMC AI v5.7.1";
   L[ln++]=" SIGNAL ENGINE / SETUP-RETEST";
   L[ln++]="=======================";
   string signal;
   if(InpUseRetestLifecycle)
   {
      if(g_trade_setup.valid)
         signal=StringFormat("%s CONFIRMED",g_trade_setup.is_buy?"BUY":"SELL");
      else if(g_active_setup.active && g_active_setup.state=="RETEST")
         signal=StringFormat("%s RETEST...",g_active_setup.is_buy?"BUY":"SELL");
      else if(g_active_setup.active && g_active_setup.state=="READY")
         signal=StringFormat("%s SETUP - wait @ %s-%s",g_active_setup.is_buy?"BUY":"SELL",
                             DoubleToString(g_active_setup.zone_bottom,dg),DoubleToString(g_active_setup.zone_top,dg));
      else
         signal="NO TRADE";
   }
   else
      signal=g_trade_setup.valid ? (g_trade_setup.is_buy?"BUY":"SELL") : "WAIT";
   L[ln++]="---- DECISION ----";
   L[ln++]="Calibration: INSUFFICIENT DATA";
   L[ln++]="Causal replay: NOT VALIDATED";
   L[ln++]=StringFormat("Grade %-3s %s",g_trade_setup.quality_grade,g_trade_setup.institutional_grade);
   L[ln++]=StringFormat("Signal %s",signal);
   if(g_active_setup.active && g_active_setup.id!="") L[ln++]=StringFormat("SetupID %s",StringSubstr(g_active_setup.id,0,20));
   L[ln++]=StringFormat("Score %s %d/100",BuildConfidenceBar(g_trade_setup.confidence),g_trade_setup.confidence);
   L[ln++]=StringFormat("Evidence %s %d/100",BuildConfidenceBar(g_trade_setup.evidence_score),g_trade_setup.evidence_score);
   if(g_trade_setup.valid)
   {
      L[ln++]=StringFormat("Risk %s %.1f pips",g_trade_setup.risk_level,g_trade_setup.risk_pips);
      L[ln++]=StringFormat("RR 1:%.1f 1:%.1f 1:%.1f",g_trade_setup.rr1,g_trade_setup.rr2,g_trade_setup.rr3);
   }
   L[ln++]="";
   if(g_trade_setup.blocker_count>0)
   {
      L[ln++]="---- BLOCKERS ----";
      for(int r=0;r<g_trade_setup.blocker_count;r++) L[ln++]="x "+g_trade_setup.blockers[r];
      L[ln++]="";
   }
   if(InpShowQualityPanel && InpShowScoreBreakdown)
   {
      L[ln++]="--- Score Breakdown ---";
      L[ln++]=StringFormat("Structure %3.0f x.25",g_score.structure);
      L[ln++]=StringFormat("Liquidity %3.0f x.20",g_score.liquidity);
      L[ln++]=StringFormat("OrderBlock %3.0f x.20",g_score.orderblock);
      L[ln++]=StringFormat("FVG %3.0f x.10",g_score.fvg);
      L[ln++]=StringFormat("Session %3.0f x.10",g_score.session);
      L[ln++]=StringFormat("HTF Bias %3.0f x.10",g_score.htf);
      L[ln++]=StringFormat("Algorithms %3.0f x.05",g_score.algo);
      L[ln++]=StringFormat("FINAL %3d",g_trade_setup.weighted_score);
      L[ln++]="";
   }
   if(g_trade_setup.valid)
   {
      L[ln++]="---- TARGETS ----";
      L[ln++]=StringFormat("Entry %s",DoubleToString(g_trade_setup.entry,dg));
      L[ln++]=StringFormat("SL %s",DoubleToString(g_trade_setup.sl,dg));
      L[ln++]=StringFormat("TP1 %s [%s]",DoubleToString(g_trade_setup.tp1,dg),g_trade_setup.tp1_type);
      L[ln++]=StringFormat("TP2 %s [%s]",DoubleToString(g_trade_setup.tp2,dg),g_trade_setup.tp2_type);
      L[ln++]=StringFormat("TP3 %s [%s]",DoubleToString(g_trade_setup.tp3,dg),g_trade_setup.tp3_type);
      L[ln++]="";
   }
   string trend=(c[total-1]>BufEmaSlow[total-1])?"BULLISH":"BEARISH";
   L[ln++]="---- CONTEXT ----";
   L[ln++]=StringFormat("Trend %s",trend);
   L[ln++]=StringFormat("ADX %.1f %s",g_adx,g_adx>=InpADXTrendLevel?"TREND":(g_adx<InpADXChopLevel?"CHOP":"MILD"));
   L[ln++]=StringFormat("HTF Bias %s",g_htf_bias==1?"BULL":(g_htf_bias==-1?"BEAR":"NEUTRAL"));
   L[ln++]=StringFormat("ATR %s",DoubleToString(g_atr,dg));
   L[ln++]=StringFormat("Spread %d pts%s",(int)g_spread,(g_is_backtest && InpIgnoreSpreadInBacktest)?" (bypass)":(InpIgnoreSpreadOffHours?" (bypass)":""));
   L[ln++]=StringFormat("Mode %s",InpRealTimeZones ? (InpUpdateEveryTick ? "REALTIME-TICK" : "REALTIME-BAR") : "CONFIRMED");
   if(InpShowLatencyInPanel)
      L[ln++]=StringFormat("Latency N:%d Disp:%.1f Confirm:%d",InpSwingFractalN,InpDisplacementATR,InpMinRightConfirmBars);
   if(InpUseBitMasking) L[ln++]=StringFormat("Mask %s",IntegerToBinary(g_signal_mask));
   else
   {
      int num_flags=0;
      for(int i=0;i<FLAG_COUNT;i++) if(g_signal_flags[i]) num_flags++;
      L[ln++]=StringFormat("Factors BOOL %d/%d",num_flags,FLAG_COUNT);
   }
   L[ln++]=StringFormat("Knap/DP %d / %d max %d",g_trade_setup.knapsack_score,g_trade_setup.dp_optimal_score,g_trade_setup.max_factor_value);
   if(InpShowDebugCounts)
      L[ln++]=StringFormat("Objects OB:%d FVG:%d LQ:%d ZN:%d BL:%d",ArraySize(g_order_blocks),ArraySize(g_fvgs),ArraySize(g_liquidity),ArraySize(g_zones),ArraySize(g_setup_blacklist));
   L[ln++]=StringFormat("Signals %d | RT:%s",g_signal_count, InpRealTimeZones ? "ON" : "OFF");
   L[ln++]="";
   L[ln++]="---- CONFLUENCE ----";
   for(int r=0;r<g_trade_setup.reason_count && r<InpPanelMaxReasons;r++) L[ln++]=L_Trim(g_trade_setup.reasons[r]);
   int font=(InpPanelFontSize>0)?InpPanelFontSize:(InpDeclutter?8:9);
   int step=font+4;
   int maxlen=0;
   for(int i=0;i<ln;i++) maxlen=MathMax(maxlen,StringLen(L[i]));
   int char_w=(font<=8)?6:7;
   int width=InpPanelAutoWidth?MathMax(240,20+maxlen*char_w):(InpDeclutter?300:340);
   g_dash_width=width;
   int chart_w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   if(chart_w<=0) chart_w=1900;
   int bg_x=chart_w-InpPanelRightPad-width;
   if(bg_x<5) bg_x=5;
   int txt_x=bg_x+8;
   for(int i=ln;i<g_dash_lines;i++) ObjectDelete(0,PFX+"DASH_"+IntegerToString(i));
   g_dash_lines=ln;
   string bg=PFX+"DASH_BG";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,10);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'10,10,16');
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   }
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,bg_x);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,16+ln*step);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,GradeColor(g_trade_setup.quality_grade));
   for(int i=0;i<ln;i++)
   {
      string name=PFX+"DASH_"+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      }
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,txt_x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,14+i*step);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font);
      ObjectSetString(0,name,OBJPROP_TEXT,NormText(L[i]));
      color col=clrSilver;
      if(StringFind(L[i],"Quantum SMC")>=0) col=clrGold;
      else if(StringFind(L[i],"BLOCKERS")>=0) col=clrOrangeRed;
      else if(StringSubstr(L[i],0,2)=="x ") col=clrOrangeRed;
      else if(StringSubstr(L[i],0,2)=="+ ") col=clrGold;
      else if(StringFind(L[i],"Grade")>=0) col=GradeColor(g_trade_setup.quality_grade);
      else if(StringFind(L[i],"Signal")>=0) col=g_trade_setup.valid ? (g_trade_setup.is_buy?clrLime:clrRed):clrGray;
      else if(StringFind(L[i],"FINAL")>=0) col=clrAqua;
      else if(StringFind(L[i],"Risk")>=0) col=(g_trade_setup.risk_level=="LOW")?clrLime:(g_trade_setup.risk_level=="MEDIUM")?clrYellow:clrOrangeRed;
      else if(StringFind(L[i],"Score ")>=0) col=PctColor(g_trade_setup.confidence);
      else if(StringFind(L[i],"Evidence ")>=0) col=PctColor(g_trade_setup.evidence_score);
      else if(StringFind(L[i],"CHOP")>=0) col=clrOrangeRed;
      else if(StringFind(L[i],"TREND")>=0) col=clrLime;
      else if(StringFind(L[i],"TP")>=0) col=clrDeepSkyBlue;
      else if(StringFind(L[i],"Entry")>=0) col=clrLime;
      else if(StringFind(L[i],"SL ")>=0) col=clrOrangeRed;
      else if(StringFind(L[i],"Latency")>=0) col=clrGoldenrod;
      else if(StringFind(L[i],"----")>=0) col=clrDimGray;
      else if(StringFind(L[i],"====")>=0) col=clrGoldenrod;
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   }
}
string L_Trim(const string s)
{
   string r=s; StringTrimLeft(r); StringTrimRight(r); return r;
}
color GradeColor(const string g)
{
   if(g=="A+") return clrGold;
   if(g=="A") return clrLime;
   if(g=="B") return clrYellow;
   if(g=="C") return clrOrange;
   return clrGray;
}
color PctColor(const int p)
{
   if(p>=85) return clrLime;
   if(p>=70) return clrGreenYellow;
   if(p>=55) return clrYellow;
   return clrOrange;
}
void DrawMTFPanel()
{
   ENUM_TIMEFRAMES tfs[]={InpMTF1,InpMTF2,InpMTF3,InpMTF4,InpMTF5};
   int bullish=0;
   string L[]; ArrayResize(L,16);
   int ln=0;
   L[ln++]="-- MTF Trend --";
   for(int i=0;i<5;i++)
   {
      double buf[]; ArraySetAsSeries(buf,false);
      CopyBuffer(h_ema_mtf[i],0,0,1,buf);
      double ema=(ArraySize(buf)>0)?buf[0]:0;
      double cl=iClose(_Symbol,tfs[i],0);
      bool up=(cl>ema && ema>0);
      if(up) bullish++;
      L[ln++]=StringFormat("%-5s %s",TFName(tfs[i]),up?"UP":"DN");
   }
   int alignment=(bullish*100)/5;
   L[ln++]=StringFormat("Align %d%%",alignment);
   int font=8,step=13;
   string bg=PFX+"MTF_BG";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,10);
      ObjectSetInteger(0,bg,OBJPROP_XSIZE,130);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'10,10,16');
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_COLOR,clrGoldenrod);
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   }
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,16+ln*step);
   for(int i=0;i<ln;i++)
   {
      string name=PFX+"MTF_"+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_XDISTANCE,20);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font);
         ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      }
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,16+i*step);
      ObjectSetString(0,name,OBJPROP_TEXT,NormText(L[i]));
      color col=clrSilver;
      if(StringFind(L[i]," UP")>=0) col=clrLime;
      else if(StringFind(L[i]," DN")>=0) col=clrRed;
      else if(StringFind(L[i],"Align")>=0) col=PctColor(alignment);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   }
}
//--------------------------------------------------------------------
void DrawSetupZone(const int total,const datetime &t[])
{
   string name=PFX+"SETUPZONE";
   string lname=name+"_L";
   if(!InpUseRetestLifecycle || !g_active_setup.active ||
      (g_active_setup.state!="READY" && g_active_setup.state!="RETEST"))
   {
      ObjectDelete(0,name); ObjectDelete(0,lname);
      return;
   }
   color col = (g_active_setup.state=="READY") ? clrGoldenrod : clrDeepSkyBlue;
   string label = StringFormat("%s %s %s",
                               g_active_setup.is_buy?"BUY":"SELL",
                               g_active_setup.state=="READY" ? "SETUP - WAIT" : "RETEST",
                               g_active_setup.state=="READY" ? "" : "- CONFIRM?");

   datetime t1 = g_active_setup.created_time;
   datetime t2 = t[total-1] + (datetime)(PeriodSeconds()*15);

   DrawZoneBox(name,t1,g_active_setup.zone_top,t2,g_active_setup.zone_bottom,col,label,80);
   DrawTextLabel(lname,t1,g_active_setup.zone_top,label,col,true,8);
}
void DrawTradeBox()
{
   if(!g_trade_setup.valid) return;
   int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   string L[]; ArrayResize(L,10);
   int ln=0;
   L[ln++]=StringFormat("%s [%s]",g_trade_setup.is_buy?"BUY":"SELL",g_trade_setup.quality_grade);
   L[ln++]=StringFormat("Score %d E %d",g_trade_setup.confidence,g_trade_setup.evidence_score);
   L[ln++]=StringFormat("Risk %s %.1fp",g_trade_setup.risk_level,g_trade_setup.risk_pips);
   L[ln++]=StringFormat("Entry %s",DoubleToString(g_trade_setup.entry,dg));
   L[ln++]=StringFormat("SL %s",DoubleToString(g_trade_setup.sl,dg));
   L[ln++]=StringFormat("TP1 %s",DoubleToString(g_trade_setup.tp1,dg));
   L[ln++]=StringFormat("TP2 %s",DoubleToString(g_trade_setup.tp2,dg));
   L[ln++]=StringFormat("TP3 %s",DoubleToString(g_trade_setup.tp3,dg));
   int font=8,step=13;
   int maxlen=0;
   for(int i=0;i<ln;i++) maxlen=MathMax(maxlen,StringLen(L[i]));
   int width=MathMax(120,20+maxlen*6);
   string bg=PFX+"TRADE_BOX_BG";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,10);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'10,10,16');
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   }
   color box_border=g_trade_setup.is_buy?clrLime:clrRed;
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,16+ln*step);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,box_border);
   for(int i=0;i<ln;i++)
   {
      string name=PFX+"TBOX_"+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font);
         ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      }
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,18);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,14+(ln-1-i)*step);
      ObjectSetString(0,name,OBJPROP_TEXT,NormText(L[i]));
      color col=clrWhite;
      if(StringFind(L[i],"BUY")>=0) col=clrLime;
      else if(StringFind(L[i],"SELL")>=0) col=clrRed;
      else if(StringFind(L[i],"Risk")>=0) col=(g_trade_setup.risk_level=="LOW")?clrLime:(g_trade_setup.risk_level=="MEDIUM")?clrYellow:clrOrangeRed;
      else if(StringFind(L[i],"TP")>=0) col=clrDeepSkyBlue;
      else if(StringFind(L[i],"SL")>=0) col=clrOrangeRed;
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   }
}
void DrawTradeLevels(const int total,const datetime &t[])
{
   bool b=g_trade_setup.is_buy;
   color gcol=GradeColor(g_trade_setup.quality_grade);
   DrawHLine(PFX+"ENTRY",g_trade_setup.entry,gcol,StringFormat("ENTRY %s",b?"BUY":"SELL"),2);
   DrawHLine(PFX+"SL",g_trade_setup.sl,clrRed,"SL",2);
   DrawHLine(PFX+"TP1",g_trade_setup.tp1,clrDeepSkyBlue,"TP1",1);
   DrawHLine(PFX+"TP2",g_trade_setup.tp2,clrDodgerBlue,"TP2",1);
   DrawHLine(PFX+"TP3",g_trade_setup.tp3,clrGold,"TP3",1);
   datetime at = (InpUseRetestLifecycle && g_active_setup.confirmed_bar>=0)
                 ? g_active_setup.confirmed_time
                 : t[total-1];
   // fallback if confirmed_time not set yet but we are in legacy mode, use live time
   if(at==0) at=t[total-1];
   string an=PFX+"ENTRY_ARROW";
   if(ObjectFind(0,an)<0) ObjectCreate(0,an,OBJ_ARROW,0,at,g_trade_setup.entry);
   ObjectSetInteger(0,an,OBJPROP_ARROWCODE,b?233:234);
   ObjectSetInteger(0,an,OBJPROP_COLOR,b?clrLime:clrRed);
   ObjectSetInteger(0,an,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,an,OBJPROP_SELECTABLE,false);
   ObjectMove(0,an,0,at,g_trade_setup.entry);
   datetime at2=at+(datetime)(PeriodSeconds()*6);
   string cn=PFX+"CONNECT";
   if(ObjectFind(0,cn)<0) ObjectCreate(0,cn,OBJ_TREND,0,at2,g_trade_setup.sl,at2,g_trade_setup.tp3);
   ObjectMove(0,cn,0,at2,g_trade_setup.sl);
   ObjectMove(0,cn,1,at2,g_trade_setup.tp3);
   ObjectSetInteger(0,cn,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,cn,OBJPROP_COLOR,clrGray);
   ObjectSetInteger(0,cn,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,cn,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,cn,OBJPROP_BACK,false);
   ObjectSetInteger(0,cn,OBJPROP_SELECTABLE,false);
}
void DrawLevelText(const string name,const datetime tm,const double price,const string text,const color col)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_TEXT,0,tm,price);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,name,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   }
   ObjectSetString(0,name,OBJPROP_TEXT," "+text);
   ObjectMove(0,name,0,tm,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
}
void DrawPDHPDL()
{
   double pdh = (g_d1_high>0? g_d1_high : iHigh(_Symbol,PERIOD_D1,1));
   double pdl = (g_d1_low>0? g_d1_low : iLow(_Symbol,PERIOD_D1,1));
   DrawHLine(PFX+"PDH",pdh,clrTomato,"PDH",2);
   DrawHLine(PFX+"PDL",pdl,clrDeepSkyBlue,"PDL",2);
}
void DrawPivotPoints()
{
   double H=(g_d1_high>0? g_d1_high : iHigh(_Symbol,PERIOD_D1,1));
   double Lo=(g_d1_low>0? g_d1_low : iLow(_Symbol,PERIOD_D1,1));
   double C=(g_d1_close>0? g_d1_close : iClose(_Symbol,PERIOD_D1,1));
   double pp=(H+Lo+C)/3.0;
   DrawHLine(PFX+"PP",pp,clrWhite,"PP",1);
   DrawHLine(PFX+"R1",2*pp-Lo,clrLime,"R1",1);
   DrawHLine(PFX+"S1",2*pp-H,clrRed,"S1",1);
}
void DrawCamarilla()
{
   double H=(g_d1_high>0? g_d1_high : iHigh(_Symbol,PERIOD_D1,1));
   double Lo=(g_d1_low>0? g_d1_low : iLow(_Symbol,PERIOD_D1,1));
   double C=(g_d1_close>0? g_d1_close : iClose(_Symbol,PERIOD_D1,1));
   double rng=H-Lo;
   DrawHLine(PFX+"CamH4",C+rng*1.1/2.0,clrDarkGreen,"H4",1);
   DrawHLine(PFX+"CamL4",C-rng*1.1/2.0,clrDarkRed,"L4",1);
}
void DrawSessionHighLow(const int total,const datetime &t[],const double &h[],const double &l[])
{
   datetime today=DayAnchor(t[total-1]);
   double sh=-DBL_MAX,sl=DBL_MAX;
   for(int i=total-1;i>=0;i--)
   {
      if(t[i]<today) break;
      if(h[i]>sh) sh=h[i];
      if(l[i]<sl) sl=l[i];
   }
   if(sh>-DBL_MAX) DrawHLine(PFX+"SESS_HIGH",sh,clrYellow,"Session High",1);
   if(sl<DBL_MAX) DrawHLine(PFX+"SESS_LOW",sl,clrYellow,"Session Low",1);
}
//====================================================================
// PRIMITIVES
//====================================================================
void DrawHLine(const string name,const double price,const color col,const string label,const int width=1)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price))
      { DebugError("DrawHLine","ObjectCreate failed for "+name,GetLastError()); return; }
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TEXT,label);
   }
   else ObjectSetDouble(0,name,OBJPROP_PRICE,price);
}
void DrawTextLabel(const string name,const datetime tm,const double price,const string text,const color col,const bool above,const int font_size=8)
{
   // v5.7.0 (R8): existing labels are UPDATED (position/text/colour) instead of
   // being left where they were first created.
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_TEXT,0,tm,price))
      { DebugError("DrawTextLabel","ObjectCreate failed for "+name,GetLastError()); return; }
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font_size);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   }
   else ObjectMove(0,name,0,tm,price);
   ObjectSetString(0,name,OBJPROP_TEXT," "+text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER);
}
void DrawFibLine(const string name,const datetime t1,const datetime t2,const double price,const color col,const int style=STYLE_DOT,const int width=1)
{
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_TREND,0,t1,price,t2,price);
      ObjectSetInteger(0,name,OBJPROP_COLOR,col);
      ObjectSetInteger(0,name,OBJPROP_STYLE,style);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   }
}
void DrawZoneBox(const string name,const datetime t1,const double p1,const datetime t2,const double p2,const color col,const string label,const int transparency=88)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,p1,t2,p2))
      { DebugError("DrawZoneBox","ObjectCreate failed for "+name,GetLastError()); return; }
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_COLOR,BlendColor(col,100-transparency));
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TEXT,label);
   }
   else
   {
      // delta update: move if needed
      ObjectMove(0,name,0,t1,p1);
      ObjectMove(0,name,1,t2,p2);
   }
}
double SafeVal(const double &arr[]){return (ArraySize(arr)>0)?arr[0]:0.0;}
color BlendColor(const color col,const int pct)
{
   int r=(int)MathRound((double)(((int)col)&0xFF)*pct/100.0);
   int g=(int)MathRound((double)((((int)col)>>8)&0xFF)*pct/100.0);
   int b=(int)MathRound((double)((((int)col)>>16)&0xFF)*pct/100.0);
   return (color)(r | (g<<8) | (b<<16));
}
string NormText(const string s){return (s=="")?" ":s;}
string TFName(const ENUM_TIMEFRAMES tf)
{
   string s=EnumToString(tf);
   StringReplace(s,"PERIOD_","");
   return s;
}
string IntegerToBinary(const int num)
{
   string r="";
   for(int i=10;i>=0;i--) r+=((num & (1<<i))!=0)?"1":"0";
   return r;
}
//+------------------------------------------------------------------+
