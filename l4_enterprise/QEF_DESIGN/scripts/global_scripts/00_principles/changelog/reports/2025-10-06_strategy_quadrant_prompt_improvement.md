# Strategy Quadrant Analysis Prompt Improvement

**Date**: 2025-10-06
**Principle**: MP123 (AI Prompt Configuration Management)
**Component**: positionStrategy (Four-Quadrant Strategy Analysis)
**File**: `scripts/global_scripts/30_global_data/parameters/scd_type1/list_openai_prompt.yaml`

## Problem Analysis

### Critical Issues Identified

1. **No Framework Context**
   - Original prompt just said "根據四象限策略分析結果" without explaining what the four quadrants mean
   - AI couldn't understand the strategic meaning behind each quadrant
   - No explanation of the IPA (Importance-Performance Analysis) framework

2. **Unclear Data Structure**
   - Just mentioned `{strategy_data}` without explaining the format
   - No clarification that data is comma-separated attribute names
   - Missing connection between data variables and their strategic positions

3. **Vague Strategic Guidance**
   - Said "只顯示該產品實際有因素的部分" but didn't explain WHY each quadrant matters
   - No clear action guidance for each quadrant type
   - Missing the fundamental strategic logic:
     - **訴求** (Appeal) = Leverage strengths in marketing
     - **改善** (Improve) = Fix critical weaknesses
     - **劣勢** (Weakness) = Accept or minimize
     - **改變** (Change) = Reposition or de-emphasize

4. **No Real-World Examples**
   - Generic instructions without concrete examples
   - No guidance on HOW to write compelling ad copy
   - Missing storytelling techniques for each quadrant

## Four-Quadrant Framework Explanation

### What the Positioning Chart Actually Shows

```
              High Importance
                     ↑
                     |
         改善        |        訴求
      (Improve)     |      (Appeal)
    High Imp +      |    High Imp +
    Negative Perf   |   Positive Perf
                    |
    ----------------+----------------→ Performance
                    |           (from negative to positive)
                    |
         劣勢        |        改變
      (Weakness)    |      (Change)
    Low Imp +       |    Low Imp +
    Negative Perf   |   Positive Perf
                    |
                    ↓
              Low Importance
```

### Data Flow from Component to Prompt

From `positionStrategy.R` (lines 293-302):

```r
# Strategy analysis generates four text strings:
appeal_text <- format_keys(appeal_factors)          # Top-right quadrant
improvement_text <- format_keys(improvement_factors) # Top-left quadrant
weakness_text <- format_keys(weakness_factors)       # Bottom-left quadrant
change_text <- format_keys(change_factors)           # Bottom-right quadrant
```

Each text string contains comma-separated attribute names like:
- "配送快速, 賣家溝通良好, 產品符合描述"

## Solution Implementation

### 1. Framework Context Section

Added comprehensive IPA framework explanation:

```yaml
## 四象限定位分析架構說明

本分析基於「重要性-績效分析」(Importance-Performance Analysis, IPA) 框架，將產品屬性分為四個策略象限：

- **訴求象限** (高重要性 + 正向績效)：客戶重視且產品表現優異的優勢屬性，應在行銷中強力突出
- **改善象限** (高重要性 + 負向績效)：客戶重視但產品表現不佳的弱點，需優先改善
- **劣勢象限** (低重要性 + 負向績效)：客戶不太重視且表現不佳，接受現況或低優先級改善
- **改變象限** (低重要性 + 正向績效)：產品表現良好但客戶不太重視，可淡化或轉化為差異化優勢
```

**Why This Matters**:
- AI now understands the 2x2 matrix structure
- Clear definition of what each quadrant represents
- Strategic implications built into the framework explanation

### 2. Clarified Data Structure

Added explicit data format explanation:

```yaml
## 產品四象限分析資料

以下是該產品在各象限的屬性因素（逗號分隔的屬性名稱）：

**訴求象限**（高重要性 + 正向績效）：
{appeal_factors}

**改善象限**（高重要性 + 負向績效）：
{improvement_factors}

**劣勢象限**（低重要性 + 負向績效）：
{weakness_factors}

**改變象限**（低重要性 + 正向績效）：
{change_factors}
```

**Why This Matters**:
- AI knows data format is comma-separated attribute names
- Clear connection between data variables and quadrant positions
- Explicit quadrant labels with strategic meaning

### 3. Detailed Strategic Guidance for Each Quadrant

#### Quadrant 1: 訴求 (Appeal) - Top Right

**Strategic Meaning**: High importance + Good performance = Marketing strengths

**Action Framework**:
```yaml
針對每一個訴求因素，提供：
1. **行銷策略**：如何在產品頁面、廣告、社交媒體中突出此優勢
2. **廣告文案範例**：具體、吸引人的文案（50字內）
3. **故事敘事建議**：如何用故事化方式呈現此優勢
4. **差異化定位**：如何將此優勢轉化為與競爭對手的區別點
```

**Real Example**:
- Factor: "配送快速" (Fast Shipping)
- Marketing Strategy: Emphasize "頂尖物流合作" in title and hero image
- Ad Copy: "與全球頂級物流合作，讓您的等待更短、驚喜更快"
- Storytelling: Share customer surprise moments receiving faster than expected
- Differentiation: Offer "預估到貨日期追蹤" vs competitors' vague shipping times

#### Quadrant 2: 改善 (Improve) - Top Left

**Strategic Meaning**: High importance + Poor performance = Critical to fix

**Action Framework**:
```yaml
針對每一個改善因素，提供：
1. **短期策略**（1-3個月）：
   - 補償機制：優惠券、延長保固、客服升級等
   - 透明溝通：誠實說明現況但強調其他優勢
2. **長期策略**（3-12個月）：
   - 改進目標：明確的改善方向和預期成果
   - 資源需求：投資、團隊、時間
3. **進度溝通**：如何向客戶展示改進進度
```

**Real Example**:
- Factor: "客服回應速度" (Customer Service Speed)
- Short-term: Add "24小時內必回覆" promise with penalty (discount code if late)
- Long-term: Hire multilingual team, implement AI chatbot, reduce response time 8h→2h
- Progress Communication: Monthly "客服改進進度報告" on social media with trend charts

#### Quadrant 3: 劣勢 (Weakness) - Bottom Left

**Strategic Meaning**: Low importance + Poor performance = Accept/minimize

**Action Framework**:
```yaml
針對每一個劣勢因素，提供：
1. **接受策略**：為何不值得大量投資（客戶不重視 + 表現不佳）
2. **淡化策略**：如何避免提及，將焦點轉移到訴求因素
3. **最低限度改善**：用最少資源達到「可接受」水平
```

**Real Example**:
- Factor: "包裝豪華度" (Packaging Luxury)
- Accept: Data shows customers care more about product than packaging
- Minimize: Don't show packaging photos, focus on product details and use scenarios
- Minimal Fix: Keep current packaging but add handwritten thank-you card (low cost, high impact)

#### Quadrant 4: 改變 (Change) - Bottom Right

**Strategic Meaning**: Low importance + Good performance = Reposition or de-emphasize

**Action Framework**:
```yaml
針對每一個改變因素，提供：
1. **重新定位**：將此優勢重新包裝，連結到客戶更重視的價值點
2. **市場教育**：如何教育客戶理解此因素的重要性
3. **淡化策略**：如果無法轉化，降低行銷比重
```

**Real Example**:
- Factor: "材質耐用度" (Durability)
- Reposition: Connect durability to "環保永續" and "長期省錢" (trending values)
- Market Education: Create comparison video showing 5-year total cost vs cheap alternatives
- De-emphasize: If target customers prefer frequent replacement, highlight "時尚設計" instead

### 4. Cross-Border E-commerce Constraints

Added explicit do's and don'ts:

```yaml
## 輸出格式要求

4. **跨境電商限制**：
   - ❌ 不可提及：隔日送達、24小時到貨、當日配送、縣市區域、分期零利率、貨到付款
   - ✅ 可以提及：國際物流合作、預估到貨時間追蹤、全球配送、信用卡分期（由銀行提供）
```

**Why This Matters**:
- Prevents AI from suggesting unrealistic shipping promises
- Avoids Taiwan-specific references (counties/cities) that don't apply to global markets
- Ensures compliance with cross-border e-commerce realities

## Technical Implementation Details

### Variable Substitution Pattern

From `positionStrategy.R` (lines 828-831):

```r
user_content <- prompt_config$user_prompt_template
user_content <- gsub("{appeal_factors}", current_strategy$appeal_text %||% "", user_content, fixed = TRUE)
user_content <- gsub("{improvement_factors}", current_strategy$improvement_text %||% "", user_content, fixed = TRUE)
user_content <- gsub("{weakness_factors}", current_strategy$weakness_text %||% "", user_content, fixed = TRUE)
user_content <- gsub("{change_factors}", current_strategy$change_text %||% "", user_content, fixed = TRUE)
```

The prompt now receives actual attribute names like:
- `{appeal_factors}` → "配送快速 • 賣家溝通良好 • 產品符合描述"
- `{improvement_factors}` → "客服回應速度 • 退換貨流程"
- etc.

### Conditional Display Logic

The prompt instructs AI to:
1. Check if each quadrant has factors
2. Only output sections for non-empty quadrants
3. Maintain markdown structure without code fences

This matches the R component's conditional logic where empty strings indicate no factors in that quadrant.

## Expected Outcomes

### Before (Issues)

AI would receive:
```
根據四象限策略分析結果，為該產品提供具體的行銷策略建議...
四象限分析資料：{strategy_data}
```

Problems:
- What does "四象限" mean? AI doesn't know
- What's in `{strategy_data}`? Format unknown
- What should I do for each quadrant? No guidance
- Result: Generic, unfocused recommendations

### After (Improvements)

AI now receives:
```
## 四象限定位分析架構說明
[Full IPA framework explanation]

## 產品四象限分析資料
**訴求象限**（高重要性 + 正向績效）：配送快速, 賣家溝通良好
**改善象限**（高重要性 + 負向績效）：客服回應速度
...

## 策略分析要求
### 訴求（如有此象限因素）
**策略方向**：強化行銷訊息，放大優勢
[Detailed action framework with examples]
...
```

Expected results:
- ✅ AI understands the 2x2 IPA framework
- ✅ Clear data structure (comma-separated attribute names)
- ✅ Specific strategic actions for each quadrant type
- ✅ Real-world examples guiding output quality
- ✅ Cross-border e-commerce compliance
- ✅ Concrete, actionable marketing recommendations

## Validation Checklist

To test the improved prompt:

1. **Framework Understanding**
   - [ ] AI correctly identifies quadrant strategic meanings
   - [ ] Recommendations align with IPA framework logic

2. **Data Interpretation**
   - [ ] AI parses comma-separated attribute names correctly
   - [ ] Each attribute gets individual strategic treatment

3. **Strategic Depth**
   - [ ] 訴求 factors get amplification strategies
   - [ ] 改善 factors get short-term + long-term plans
   - [ ] 劣勢 factors get acceptance/minimization strategies
   - [ ] 改變 factors get repositioning/education strategies

4. **Output Quality**
   - [ ] Concrete ad copy examples (not generic templates)
   - [ ] Storytelling approaches with emotional hooks
   - [ ] Differentiation strategies vs competitors
   - [ ] No cross-border e-commerce violations

5. **Conditional Display**
   - [ ] Empty quadrants are completely skipped
   - [ ] Only relevant sections appear in output
   - [ ] Markdown structure maintained

## Principles Applied

- **MP123**: AI Prompt Configuration Management - Centralized prompt templates with clear structure
- **MP031**: Separation of Concerns - Clear separation between data preparation (R component) and analysis guidance (YAML prompt)
- **MP032**: DRY Principle - Reusable prompt templates loaded from centralized configuration
- **MP099**: Defensive Programming - Explicit data format specification prevents misinterpretation

## Files Modified

1. **Main File**:
   - `scripts/global_scripts/30_global_data/parameters/scd_type1/list_openai_prompt.yaml`
   - Section: `position_analysis.strategy_quadrant_analysis.user_prompt_template`
   - Lines: 88-207 (expanded from 88-120)

2. **No Code Changes Required**:
   - `positionStrategy.R` component already provides correct data structure
   - Variable substitution pattern remains unchanged
   - API call logic unaffected

## Future Enhancements

Potential improvements for future iterations:

1. **Maslow's Hierarchy Integration**
   - Connect attributes to psychological needs (similar to market_track_strategy prompt)
   - "配送快速" → Safety need (reliability, reduce anxiety)
   - "品質優良" → Self-esteem need (show capability, prestige)

2. **Competitive Benchmarking**
   - Add section comparing each quadrant to competitor positioning
   - "Your 訴求 factors vs competitor's 劣勢 factors = attack opportunity"

3. **A/B Testing Guidance**
   - Suggest specific A/B test scenarios for each strategy
   - Example: "Test 'fast shipping' emphasis in title vs hero image"

4. **ROI Prioritization**
   - Add expected impact/effort matrix for each recommendation
   - Help prioritize which strategies to implement first

## Conclusion

This improvement transforms the `strategy_quadrant_analysis` prompt from a vague request into a comprehensive strategic framework that:

1. **Educates the AI** about the IPA framework and four-quadrant logic
2. **Clarifies data structure** so AI knows how to interpret input
3. **Provides actionable templates** for each quadrant type with real examples
4. **Ensures compliance** with cross-border e-commerce constraints
5. **Generates concrete value** through specific ad copy, storytelling, and differentiation strategies

The result: AI-generated strategy recommendations that are principle-based, contextually appropriate, and immediately actionable for cross-border e-commerce marketing.
