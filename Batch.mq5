//+-----------------------------------------------------------------+
//|                      Amirhossein Hasani                         |
//                 CheckMA_Crossover_All_Symbols_5Bars.mq5          |
//|               Copyright 2024, MetaQuotes Software Corp.         |
//|                      https://www.mql5.com                       |
//+-----------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property script_show_inputs

//--- input parameters
input int                 MAPeriodFast = 9;       // دوره مووینگ اوریج سریع
input int                 MAPeriodSlow = 21;      // دوره مووینگ اوریج کند
input ENUM_MA_METHOD      MAMethod = MODE_SMA;    // روش مووینگ اوریج
input ENUM_APPLIED_PRICE  MAPrice = PRICE_CLOSE;  // قیمت اعمال مووینگ اوریج
input ENUM_TIMEFRAMES     TimeFrame = PERIOD_D1;  // تایم فریم بررسی
input int                 BarsToCheck = 5;        // تعداد کندل های مورد بررسی
input bool                ShowAllSymbols = true;  // نمایش همه نمادها

//+------------------------------------------------------------------+
//| ساختار برای ذخیره اطلاعات نماد                                  |
//+------------------------------------------------------------------+
struct SymbolData
  {
   string            symbol;
   bool              has_cross_in_period;    // آیا در دوره بررسی کراس داشته؟
   int               cross_type;             // 0: بدون کراس, 1: گلدن کراس, 2: دث کراس
   int               bars_since_cross;       // چند کندل از آخرین کراس گذشته
   double            current_distance_pips;  // فاصله فعلی
   double            cross_price_fast;       // قیمت MA سریع در لحظه کراس
   double            cross_price_slow;       // قیمت MA کند در لحظه کراس
   datetime          cross_time;             // زمان آخرین کراس
   string            status_text;            // متن وضعیت
  };

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
  {
   // پاکسازی پنجره اکسپرت
   ClearExpertWindow();
   
   int total_symbols = SymbolsTotal(true);
   Print("=== بررسی کراس مووینگ اوریج برای ", total_symbols, " نماد ===");
   Print("تایم فریم: ", EnumToString(TimeFrame), " | بررسی ", BarsToCheck, " کندل اخیر");
   Print("MA سریع: ", MAPeriodFast, " | MA کند: ", MAPeriodSlow);
   Print("======================================================");
   
   SymbolData symbols_data[];
   ArrayResize(symbols_data, total_symbols);
   
   int golden_cross_count = 0;
   int death_cross_count = 0;
   int recent_cross_count = 0; // کراس در 3 کندل اخیر
   
   // بررسی هر نماد
   for(int i = 0; i < total_symbols; i++)
     {
      string symbol_name = SymbolName(i, true);
      
      if(!SymbolSelect(symbol_name, true))
        {
         Print("خطا در انتخاب نماد ", symbol_name);
         continue;
        }
      
      Sleep(10);
      
      // بررسی کراس در چند کندل اخیر
      SymbolData data = CheckMACrossMultipleBars(symbol_name);
      symbols_data[i] = data;
      
      // آمارگیری
      if(data.cross_type == 1) // گلدن کراس
        {
         golden_cross_count++;
         if(data.bars_since_cross <= 3) recent_cross_count++;
        }
      else if(data.cross_type == 2) // دث کراس
        {
         death_cross_count++;
         if(data.bars_since_cross <= 3) recent_cross_count++;
        }
      
      // نمایش بر اساس تنظیمات
      if(ShowAllSymbols || data.cross_type > 0)
        {
         PrintSymbolResult(data);
        }
     }
   
   // نمایش گزارش
   DisplaySummaryReport(symbols_data, total_symbols, golden_cross_count, death_cross_count, recent_cross_count);
   DisplayCrossDetails(symbols_data, total_symbols);
   DisplayRecentCrosses(symbols_data, total_symbols);
  }

//+------------------------------------------------------------------+
//| بررسی کراس در چند کندل اخیر                                     |
//+------------------------------------------------------------------+
SymbolData CheckMACrossMultipleBars(string symbol)
  {
   SymbolData data;
   data.symbol = symbol;
   data.cross_type = 0;
   data.bars_since_cross = -1;
   data.has_cross_in_period = false;
   data.cross_time = 0;
   
   // ایجاد هندل ها
   int ma_fast_handle = iMA(symbol, TimeFrame, MAPeriodFast, 0, MAMethod, MAPrice);
   int ma_slow_handle = iMA(symbol, TimeFrame, MAPeriodSlow, 0, MAMethod, MAPrice);
   
   if(ma_fast_handle == INVALID_HANDLE || ma_slow_handle == INVALID_HANDLE)
     {
      data.status_text = "خطا: هندل نامعتبر";
      return data;
     }
   
   // دریافت داده برای کندل های مورد نیاز (یک کندل بیشتر برای مقایسه)
   int bars_needed = BarsToCheck + 1;
   double ma_fast[], ma_slow[];
   datetime time[];
   
   ArraySetAsSeries(ma_fast, true);
   ArraySetAsSeries(ma_slow, true);
   ArraySetAsSeries(time, true);
   
   // کپی داده ها
   if(CopyBuffer(ma_fast_handle, 0, 0, bars_needed, ma_fast) < bars_needed ||
      CopyBuffer(ma_slow_handle, 0, 0, bars_needed, ma_slow) < bars_needed)
     {
      data.status_text = "خطا: دریافت داده";
      IndicatorRelease(ma_fast_handle);
      IndicatorRelease(ma_slow_handle);
      return data;
     }
   
   // دریافت زمان کندل ها
   if(CopyTime(symbol, TimeFrame, 0, bars_needed, time) < bars_needed)
     {
      // اگر زمان دریافت نشد، ادامه می‌دهیم
     }
   
   // محاسبه فاصله فعلی
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   data.current_distance_pips = MathAbs(ma_fast[0] - ma_slow[0]) / point;
   if(digits == 3 || digits == 5) data.current_distance_pips /= 10;
   
   // بررسی کراس در کندل های اخیر (از جدید به قدیم)
   int last_cross_bar = -1;
   int cross_type = 0;
   
   for(int bar = 0; bar < BarsToCheck; bar++)
     {
      // مقادیر فعلی و قبلی
      double fast_current = ma_fast[bar];
      double fast_previous = ma_fast[bar + 1];
      double slow_current = ma_slow[bar];
      double slow_previous = ma_slow[bar + 1];
      
      // بررسی کراس صعودی
      if(fast_previous <= slow_previous && fast_current > slow_current)
        {
         last_cross_bar = bar;
         cross_type = 1; // گلدن کراس
         data.cross_price_fast = fast_current;
         data.cross_price_slow = slow_current;
         if(bar < bars_needed) data.cross_time = time[bar];
         data.has_cross_in_period = true;
        }
      // بررسی کراس نزولی
      else if(fast_previous >= slow_previous && fast_current < slow_current)
        {
         last_cross_bar = bar;
         cross_type = 2; // دث کراس
         data.cross_price_fast = fast_current;
         data.cross_price_slow = slow_current;
         if(bar < bars_needed) data.cross_time = time[bar];
         data.has_cross_in_period = true;
        }
     }
   
   // ذخیره نتایج
   if(last_cross_bar != -1)
     {
      data.cross_type = cross_type;
      data.bars_since_cross = last_cross_bar;
      
      if(cross_type == 1)
         data.status_text = StringFormat("کراس صعودی (%d کندل قبل)", last_cross_bar);
      else if(cross_type == 2)
         data.status_text = StringFormat("کراس نزولی (%d کندل قبل)", last_cross_bar);
     }
   else
     {
      // بدون کراس
      data.bars_since_cross = BarsToCheck; // یا بیشتر
      if(ma_fast[0] > ma_slow[0])
         data.status_text = StringFormat("بدون کراس (MA%d بالا)", MAPeriodFast);
      else
         data.status_text = StringFormat("بدون کراس (MA%d پایین)", MAPeriodFast);
     }
   
   // رهاسازی هندل ها
   IndicatorRelease(ma_fast_handle);
   IndicatorRelease(ma_slow_handle);
   
   return data;
  }

//+------------------------------------------------------------------+
//| نمایش نتیجه برای یک نماد                                        |
//+------------------------------------------------------------------+
void PrintSymbolResult(SymbolData &data)
  {
   string symbol_info = StringFormat("%-15s", data.symbol);
   string status_info = StringFormat("%-25s", data.status_text);
   
   if(data.cross_type > 0)
     {
      // نمایش نمادهای با کراس
      string cross_info = "";
      if(data.cross_type == 1)
         cross_info = StringFormat("↑ گلدن کراس در %d کندل قبل | فاصله فعلی: %.1f پیپ",
                                   data.bars_since_cross, data.current_distance_pips);
      else
         cross_info = StringFormat("↓ دث کراس در %d کندل قبل | فاصله فعلی: %.1f پیپ",
                                   data.bars_since_cross, data.current_distance_pips);
      
      Print(symbol_info, " | ", status_info, " | ", cross_info);
     }
   else if(ShowAllSymbols)
     {
      // نمایش نمادهای بدون کراس
      Print(symbol_info, " | ", status_info, " | فاصله فعلی: ", StringFormat("%.1f", data.current_distance_pips), " پیپ");
     }
  }

//+------------------------------------------------------------------+
//| نمایش گزارش خلاصه                                               |
//+------------------------------------------------------------------+
void DisplaySummaryReport(SymbolData &data[], int total, int golden, int death, int recent)
  {
   Print("\n" + StringRepeat("=", 60));
   Print("گزارش خلاصه:");
   Print(StringRepeat("=", 60));
   Print("تعداد کل نمادهای بررسی شده: ", total);
   Print("تعداد نمادهای با کراس در ", BarsToCheck, " کندل اخیر: ", golden + death);
   Print("  - کراس صعودی: ", golden, " نماد");
   Print("  - کراس نزولی : ", death, " نماد");
   Print("  - کراس در 3 کندل اخیر: ", recent, " نماد");
   Print("  - بدون کراس: ", total - (golden + death), " نماد");
   Print(StringRepeat("-", 60));
   Print("تاریخ بررسی: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   Print(StringRepeat("=", 60));
  }

//+------------------------------------------------------------------+
//| نمایش جزئیات کراس ها                                            |
//+------------------------------------------------------------------+
void DisplayCrossDetails(SymbolData &data[], int total)
  {
   Print("\n" + StringRepeat("=", 80));
   Print("جزئیات نمادهای با کراس:");
   Print(StringRepeat("=", 80));
   Print("نماد          | نوع کراس     | کندل های گذشته | فاصله فعلی | زمان احتمالی کراس");
   Print(StringRepeat("-", 80));
   
   bool has_any_cross = false;
   
   for(int i = 0; i < total; i++)
     {
      if(data[i].cross_type > 0)
        {
         has_any_cross = true;
         string symbol_col = StringFormat("%-12s", data[i].symbol);
         string type_col = (data[i].cross_type == 1) ? "صعودی کراس  " : "نزولی کراس    ";
         string bars_col = StringFormat("%-14s", StringFormat("%d کندل قبل", data[i].bars_since_cross));
         string distance_col = StringFormat("%-12s", StringFormat("%.1f پیپ", data[i].current_distance_pips));
         
         string time_col = "نامشخص";
         if(data[i].cross_time > 0)
            time_col = TimeToString(data[i].cross_time, TIME_DATE);
         
         Print(symbol_col, " | ", type_col, " | ", bars_col, " | ", distance_col, " | ", time_col);
        }
     }
   
   if(!has_any_cross)
      Print("هیچ کراسی در ", BarsToCheck, " کندل اخیر یافت نشد.");
   
   Print(StringRepeat("=", 80));
  }

//+------------------------------------------------------------------+
//| نمایش کراس های اخیر                                             |
//+------------------------------------------------------------------+
void DisplayRecentCrosses(SymbolData &data[], int total)
  {
   Print("\n" + StringRepeat("=", 70));
   Print("کراس های اخیر (1-3 کندل گذشته):");
   Print(StringRepeat("=", 70));
   Print("نماد          | نوع کراس     | زمان گذشته   | فاصله از کراس | وضعیت فعلی");
   Print(StringRepeat("-", 70));
   
   bool has_recent_cross = false;
   
   for(int i = 0; i < total; i++)
     {
      if(data[i].cross_type > 0 && data[i].bars_since_cross <= 3 && data[i].bars_since_cross >= 1)
        {
         has_recent_cross = true;
         string symbol_col = StringFormat("%-12s", data[i].symbol);
         string type_col = (data[i].cross_type == 1) ? "↑ صعودی" : "↓نزولی  ";
         string bars_col = StringFormat("%-12s", StringFormat("%d کندل", data[i].bars_since_cross));
         string distance_col = StringFormat("%-14s", StringFormat("%.1f پیپ", data[i].current_distance_pips));
         
         // وضعیت فعلی (آیا هنوز کراس معتبر است؟)
         string current_status = "";
         if(data[i].cross_type == 1) // گلدن کراس
           {
            current_status = (data[i].current_distance_pips > 0) ? "معتبر ✓" : "باطل ✗";
           }
         else // دث کراس
           {
            current_status = (data[i].current_distance_pips > 0) ? "معتبر ✓" : "باطل ✗";
           }
         
         Print(symbol_col, " | ", type_col, " | ", bars_col, " | ", distance_col, " | ", current_status);
        }
     }
   
   if(!has_recent_cross)
      Print("هیچ کراس تازه‌ای در 3 کندل اخیر یافت نشد.");
   
   Print(StringRepeat("=", 70));
  }

//+------------------------------------------------------------------+
//| پاکسازی پنجره اکسپرت                                            |
//+------------------------------------------------------------------+
void ClearExpertWindow()
  {
   for(int i = 0; i < 30; i++)
      Print("");
  }

//+------------------------------------------------------------------+
//| تابع تکرار رشته                                                 |
//+------------------------------------------------------------------+
string StringRepeat(string str, int count)
  {
   string result = "";
   for(int i = 0; i < count; i++)
      result += str;
   return result;
  }
