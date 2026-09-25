# Baseline dependency inventory

Source: `QuantumSMC_AI_Pro_v5.6.9_COMPACT_DASHBOARD.mq5` at `c3758d4`. Generated before source changes.

## Function calls and global state

| Function (baseline line) | Project callees | State referenced |
|---|---|---|
| GenerateOBId (669) |  |  |
| GenerateSetupId (673) | PipSize, TFName |  |
| FindOBIndexByUID (682) |  | g_order_blocks |
| IsBlacklisted (689) |  | g_setup_blacklist |
| BlacklistSetup (695) | IsBlacklisted | g_blacklist_time, g_blacklist_zone_center, g_blacklist_zone_type, g_setup_blacklist |
| IsDuplicateLiquidity (733) |  | g_liquidity |
| IsDuplicateOB (743) |  | g_order_blocks |
| LogLifecycle (754) |  |  |
| IsSameIdeaAsBlacklisted (759) | PipSize | g_atr, g_blacklist_time, g_blacklist_zone_center, g_blacklist_zone_type, g_buf_t, g_rates_total, g_setup_blacklist |
| EnforceArrayLimits (787) | BuildLiquidityPriorityIndex, BuildOBPriceIndex, BuildOBStrengthIndex | g_fvgs, g_liquidity, g_ob_strength_idx, g_order_blocks, g_structures, g_zones |
| ReevaluateFVGState (830) |  |  |
| SweepHasDisplacementOrVolume (856) | PipSize |  |
| DebugPrint (879) |  |  |
| PF (880) |  |  |
| DebugError (881) | TFName |  |
| RefreshVolatilityAndSpread (887) | DebugError | g_adx, g_atr, g_spread, h_adx, h_atr |
| IsDuplicateBreaker (900) |  | g_breakers |
| UpdateBreakerStates (907) |  | g_breakers |
| UpdateLiquiditySweeps (925) | DebugPrint, IsDuplicateLiquidity, PipSize, SweepHasDisplacementOrVolume | g_atr, g_liquidity |
| DrawPersistentSignal (959) | DebugError |  |
| SmartObjectCleanup (976) |  | g_active_setup, g_trade_setup |
| OnInit (1020) | PipSize | BufEmaFast, BufEmaSlow, BufVWAP, g_active_setup, g_blacklist_time, g_blacklist_zone_center, g_blacklist_zone_type, g_breakers, g_buf_c, g_buf_h, g_buf_l, g_buf_o, g_buf_t, g_buf_tv, g_cum_pv, g_cum_v, g_d1_cache_time, g_dash_lines, g_ema_filled, g_fvgs, g_htf_cache_time, g_is_backtest, g_kill_zones, g_last_alert_bar, g_last_alert_id, g_last_bar_time, g_last_rates_total, g_liq_priority_idx, g_liquidity, g_market_graph, g_needs_full_rebuild, g_ob_price_idx, g_ob_strength_idx, g_order_blocks, g_range, g_setup_blacklist, g_signal_count, g_str_displacement, g_str_last_high, g_str_last_low, g_str_scanned_to, g_str_trend, g_structures, g_trade_setup, g_vwap_anchor, g_vwap_closed_to, g_zones, h_adx, h_atr, h_ema_fast, h_ema_mtf, h_ema_slow, h_rsi |
| OnDeinit (1108) |  | g_signal_count, h_adx, h_atr, h_ema_fast, h_ema_mtf, h_ema_slow, h_rsi |
| OnChartEvent (1127) | RepositionDashboard | g_last_bar_time |
| RepositionDashboard (1140) |  | g_dash_lines, g_dash_width |
| OnCalculate (1167) | BuildLiquidityPriorityIndex, BuildMarketGraph, BuildOBPriceIndex, BuildOBStrengthIndex, CalculateAITradeSetup, ComputeHTFBias, DebugPrint, DetectDealingRange, DetectFVG, DetectJudasSwing, DetectKillZones, DetectLiquidity, DetectOrderBlocks, DetectStructure, DetectZones, DrawBreakerZones, DrawCamarilla, DrawFVGZones, DrawKillZones, DrawLiquidityMarkers, DrawMTFPanel, DrawPDHPDL, DrawPivotPoints, DrawPremiumDiscount, DrawQuantumDashboard, DrawSessionHighLow, DrawSetupZone, DrawStructureAndOB, DrawTextLabel, DrawTradeBox, DrawTradeLevels, DrawZones, EnforceArrayLimits, FillEMAAndVWAP, FireSetupAlert, LogLifecycle, ManageSetupLifecycle, ReevaluateFVGState, RefreshVolatilityAndSpread, SmartObjectCleanup, UpdateBreakerStates, UpdateLiquiditySweeps, UpdateSignalMask | g_active_setup, g_breakers, g_buf_c, g_buf_h, g_buf_l, g_buf_o, g_buf_t, g_buf_tv, g_ema_filled, g_fvgs, g_judas, g_judas_bar, g_kill_zones, g_last_bar_time, g_last_rates_total, g_liq_priority_idx, g_liquidity, g_market_graph, g_needs_full_rebuild, g_ob_price_idx, g_ob_strength_idx, g_order_blocks, g_rates_total, g_signal_mask, g_spread, g_str_scanned_to, g_structures, g_trade_setup, g_vwap_anchor, g_vwap_closed_to, g_zones |
| PipSize (1386) |  |  |
| OBMid (1399) |  | g_order_blocks |
| BuildOBPriceIndex (1404) | OBMid | g_ob_price_idx, g_order_blocks |
| BuildOBStrengthIndex (1419) |  | g_ob_strength_idx, g_order_blocks |
| BuildLiquidityPriorityIndex (1435) |  | g_liq_priority_idx, g_liquidity |
| BinarySearchNearestOB (1458) | OBMid | g_ob_price_idx, g_order_blocks |
| UpdateSignalMask (1482) | GetOTEZone | g_fvgs, g_htf_bias, g_judas, g_liquidity, g_order_blocks, g_range, g_signal_mask, g_structures, g_zones |
| CheckSignalPattern (1525) |  | g_signal_mask |
| AddGraphNode (1529) |  | g_market_graph |
| ConnectGraphNodes (1539) |  | g_atr, g_market_graph |
| BuildMarketGraph (1551) | AddGraphNode, BuildOBStrengthIndex, ConnectGraphNodes, OBMid | g_fvgs, g_liquidity, g_market_graph, g_ob_strength_idx, g_order_blocks |
| GraphConfluenceScore (1570) |  | g_atr, g_market_graph |
| KnapsackOptimizeSignals (1584) |  |  |
| DynamicProgrammingConfidence (1598) |  |  |
| ScoreStructure (1616) |  | g_structures |
| ScoreLiquidity (1631) |  | g_liquidity |
| ScoreOrderBlock (1648) | OBMid | g_order_blocks |
| ScoreFVG (1658) |  | g_fvgs |
| ScoreSession (1675) |  |  |
| ScoreHTF (1684) |  | g_htf_bias |
| ScoreAlgo (1690) | GraphConfluenceScore |  |
| MaxPossibleValue (1698) |  |  |
| CalculateProbability (1704) | CheckSignalPattern | g_adx, g_htf_bias, g_is_backtest, g_judas, g_spread |
| CalculateQualityGrade (1717) | CheckSignalPattern |  |
| GradeRank (1727) |  |  |
| GetInstitutionalGrade (1735) |  |  |
| CalculateRiskLevel (1744) | PipSize |  |
| BuildConfidenceBar (1759) |  |  |
| SelectEntryOB (1771) | DebugPrint, OBMid | g_order_blocks |
| PushTarget (1815) |  |  |
| GreedyFindBestTarget (1819) | PushTarget | g_d1_high, g_d1_low, g_fvgs, g_liquidity, g_order_blocks |
| AddReason (1877) |  | g_trade_setup |
| AddBlocker (1881) |  | g_trade_setup |
| CalculateAITradeSetup (1885) | AddBlocker, AddReason, CalculateProbability, CalculateQualityGrade, CalculateRiskLevel, CheckSignalPattern, DebugPrint, DynamicProgrammingConfidence, FindOBIndexByUID, GenerateSetupId, GetInstitutionalGrade, GradeRank, GreedyFindBestTarget, IsBlacklisted, IsSameIdeaAsBlacklisted, KnapsackOptimizeSignals, LogLifecycle, MaxPossibleValue, OBMid, PF, PipSize, ScoreAlgo, ScoreFVG, ScoreHTF, ScoreLiquidity, ScoreOrderBlock, ScoreSession, ScoreStructure, SelectEntryOB | g_active_setup, g_adx, g_atr, g_buf_t, g_fvgs, g_htf_bias, g_is_backtest, g_judas, g_liquidity, g_order_blocks, g_range, g_score, g_signal_count, g_spread, g_structures, g_trade_setup, g_zones |
| ManageSetupLifecycle (2317) | BlacklistSetup, DrawPersistentSignal, FindOBIndexByUID, IsSameIdeaAsBlacklisted, LogLifecycle, PF | g_active_setup, g_atr, g_order_blocks, g_signal_count, g_trade_setup |
| FireSetupAlert (2466) | TFName | g_active_setup, g_last_alert_bar, g_last_alert_id, g_trade_setup |
| FillEMAAndVWAP (2512) | DayAnchor, DebugError | BufEmaFast, BufEmaSlow, BufVWAP, g_cum_pv, g_cum_v, g_ema_filled, g_vwap_anchor, g_vwap_closed_to, h_ema_fast, h_ema_slow |
| DayAnchor (2590) |  |  |
| DetectStructure (2600) | DebugError, DebugPrint, FindLastBearishOB, FindLastBullishOB, IsFractalHigh, IsFractalLow | g_str_displacement, g_str_last_high, g_str_last_low, g_str_scanned_to, g_str_trend, g_structures, h_atr |
| IsFractalHigh (2692) |  |  |
| IsFractalLow (2700) |  |  |
| FindLastBearishOB (2707) |  |  |
| FindLastBullishOB (2712) |  |  |
| DetectOrderBlocks (2717) | AddBreakerBlock, BuildOBStrengthIndex, GenerateOBId, IsDuplicateOB | g_atr, g_ob_strength_idx, g_order_blocks, g_structures |
| AddBreakerBlock (2809) | IsDuplicateBreaker | g_breakers |
| DetectZones (2828) |  | g_zones, h_atr |
| DetectFVG (2883) | AddOrMergeFVG | h_atr |
| AddOrMergeFVG (2932) | ReevaluateFVGState | g_fvgs |
| AddOrMergeFVG_Simple (2954) |  | g_fvgs |
| DetectLiquidity (2974) | IsDuplicateLiquidity, IsFractalHigh, IsFractalLow, PipSize, SweepHasDisplacementOrVolume | g_atr, g_liquidity |
| DetectDealingRange (3026) | IsFractalHigh, IsFractalLow | g_range |
| GetOTEZone (3051) |  | g_range |
| ComputeHTFBias (3061) | DebugError, DebugPrint, TFName | g_d1_cache_time, g_d1_close, g_d1_high, g_d1_low, g_htf_bias, g_htf_cache_time, g_htf_eq, g_memo_hit |
| DetectJudasSwing (3107) | DayAnchor | g_judas, g_judas_bar |
| DetectKillZones (3129) | DayAnchor | g_kill_zones |
| DrawZones (3150) | DrawTextLabel, DrawZoneBox | g_rates_total, g_zones |
| DrawPremiumDiscount (3164) | DrawFibLine, DrawTextLabel, DrawZoneBox, GetOTEZone | g_range |
| DrawBreakerZones (3205) | DrawTextLabel, DrawZoneBox | g_breakers |
| DrawStructureAndOB (3217) | DrawTextLabel, DrawZoneBox | g_active_setup, g_order_blocks, g_structures, g_trade_setup |
| DrawFVGZones (3243) | DrawTextLabel, DrawZoneBox | g_fvgs |
| DrawLiquidityMarkers (3254) | DrawTextLabel | g_liq_priority_idx, g_liquidity |
| DrawKillZones (3288) | BlendColor, DrawTextLabel | g_kill_zones |
| DrawQuantumDashboard (3304) | BuildConfidenceBar, GradeColor, IntegerToBinary, L_Trim, NormText, PctColor | BufEmaSlow, g_active_setup, g_adx, g_atr, g_dash_lines, g_dash_width, g_fvgs, g_htf_bias, g_is_backtest, g_liquidity, g_order_blocks, g_score, g_setup_blacklist, g_signal_count, g_signal_mask, g_spread, g_trade_setup, g_zones |
| L_Trim (3453) |  |  |
| GradeColor (3457) |  |  |
| PctColor (3465) |  |  |
| DrawMTFPanel (3472) | NormText, PctColor, TFName | h_ema_mtf |
| DrawSetupZone (3529) | DrawTextLabel, DrawZoneBox | g_active_setup |
| DrawTradeBox (3551) | NormText | g_trade_setup |
| DrawTradeLevels (3609) | DrawHLine, GradeColor | g_active_setup, g_trade_setup |
| DrawLevelText (3642) |  |  |
| DrawPDHPDL (3655) | DrawHLine | g_d1_high, g_d1_low |
| DrawPivotPoints (3662) | DrawHLine | g_d1_close, g_d1_high, g_d1_low |
| DrawCamarilla (3672) | DrawHLine | g_d1_close, g_d1_high, g_d1_low |
| DrawSessionHighLow (3681) | DayAnchor, DrawHLine |  |
| DrawHLine (3697) | DebugError |  |
| DrawTextLabel (3713) | DebugError |  |
| DrawFibLine (3730) |  |  |
| DrawZoneBox (3744) | BlendColor, DebugError |  |
| SafeVal (3764) |  |  |
| BlendColor (3765) |  |  |
| NormText (3772) |  |  |
| TFName (3773) |  |  |
| IntegerToBinary (3779) |  |  |

## Data types

### ENUM_MIN_GRADE
```cpp
GRADE_D = 1, // D (accept everything)
   GRADE_C = 2, // C
   GRADE_B = 3, // B
   GRADE_A = 4, // A
   GRADE_APLUS = 5 // A+ only
```

### SStructureBreak
```cpp
int      bar;
   datetime time;
   double   price;
   bool     bullish;
   string   type;
   int      ob_bar;
   int      strength;
   int      priority;
```

### SOrderBlock
```cpp
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
```

### SFVG
```cpp
int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   bool     filled;
   string   state;
   double   mid_price;
```

### SLiquidity
```cpp
int      bar;
   datetime time;
   double   price;
   string   type;
   bool     swept;
   int      priority;
```

### SKillZone
```cpp
datetime start,end;
   double   high,low;
   string   name;
   color    col;
```

### SZone
```cpp
int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   string   state;
   int      touches;
   double   strength_score;
```

### SBreaker
```cpp
int      bar;
   datetime time1,time2;
   double   top,bottom;
   bool     bullish;
   string   state;
```

### SSignalFactor
```cpp
string name;
   int    value;
   int    weight;
   bool   active;
```

### STradeSetup
```cpp
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
   int    probability;
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
```

### SScoreBreakdown
```cpp
double structure;
   double liquidity;
   double orderblock;
   double fvg;
   double session;
   double htf;
   double algo;
   double final_score;
```

### SActiveSetup
```cpp
bool     active;
   string   id; // STABLE SETUP ID
   string   state; // READY | RETEST | CONFIRMED | INVALID
   bool     is_buy;
   int      created_bar; // for reference only
   datetime created_time; // IMMUTABLE anchor
   double   zone_top, zone_bottom;
   string   ob_uid; // STABLE
   int      ob_index_cache; // resolved each tick
   string   quality_grade;
   string   institutional_grade;
   int      confidence;
   int      probability;
   double   entry,sl,tp1,tp2,tp3;
   string   tp1_type,tp2_type,tp3_type;
   double   rr1,rr2,rr3;
   string   risk_level;
   double   risk_pips;
   int      confirmed_bar;
   datetime confirmed_time;
   bool     alert_fired;
```

### SDealingRange
```cpp
bool     valid;
   int      bar_high,bar_low;
   datetime time_high,time_low;
   double   high,low,eq;
   bool     bullish_leg;
```

### SGraphNode
```cpp
string type;
   double price;
   int    strength;
   int    links[MAX_GRAPH_LINKS];
   int    link_count;
   bool   visited;
```

### STarget
```cpp
double price;
   int    priority;
   string type;
```

## Global declarations and collections (baseline)
```cpp
datetime g_last_bar_time = 0;
int h_ema_fast, h_ema_slow, h_atr, h_adx, h_rsi;
int h_ema_mtf[5];
int g_signal_mask = 0;
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
int    g_str_trend=0;
bool   g_str_displacement=false;
int    g_str_scanned_to=-1;          // last CLOSED bar index already processed (-1 = never)
//--- v5.7.0 alert de-dup by signal identity (setup id + confirmed time + direction)
string g_last_alert_id="";
//--- v5.7.0 VWAP: cumulative sums cover CLOSED bars only; live bar is computed without mutating them
int    g_vwap_closed_to=-1;
bool   g_ema_filled=false;


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


```
