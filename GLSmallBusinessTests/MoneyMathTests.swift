//  MoneyMathTests.swift GLSmallBusinessTests
//
//  THE home for EstimateTotals — the single source of truth for subtotal/discount/tax/total/deposit
//  on every document (Estimate, Invoice base, ChangeOrder). Happy paths, then the boundaries: every
//  clamp (discount, deposit, the never-negative floor), tax scaling under a discount, the guards
//  for nonsense input (negative rate, negative discount, zero subtotal), cent rounding and very
//  large amounts. Invoice-level behaviour that sits ON TOP of these totals (change-order lines,
//  payments, balance, status) lives in InvoiceMoneyTests.

import Testing
import Foundation
@testable import GLSmallBusiness

struct MoneyMathTests {
    private func totals(_ lines: [(Double, Bool)], tax: Double = 0,
                        discountType: AdjustmentType = .none, discountValue: Double = 0,
                        depositType: AdjustmentType = .none, depositValue: Double = 0) -> EstimateTotals {
        EstimateTotals(
            lines: lines.map { (lineTotal: DomainMoney.decimal($0.0), isTaxable: $0.1) },
            taxRatePercent: tax,
            discountType: discountType, discountValue: discountValue,
            depositType: depositType, depositValue: depositValue
        )
    }

    // MARK: Subtotal + tax

    @Test func emptyLinesAreAllZero() {
        let t = totals([])
        #expect(t.subtotal == 0 && t.discount == 0 && t.tax == 0 && t.total == 0 && t.deposit == 0)
    }

    @Test func subtotalAndTaxOnTaxableLine() {
        let t = totals([(100, true)], tax: 10)
        #expect(close(t.subtotal, 100))
        #expect(close(t.tax, 10))
        #expect(close(t.total, 110))
    }

    @Test func taxOnlyAppliesToTaxableLines() {
        let t = totals([(100, true), (100, false)], tax: 10)
        #expect(close(t.subtotal, 200))
        #expect(close(t.tax, 10))   // only the $100 taxable line
        #expect(close(t.total, 210))
    }

    @Test func noTaxWhenRateIsZero() {
        let t = totals([(100, true)], tax: 0)
        #expect(t.tax == 0)
        #expect(close(t.total, 100))
    }

    @Test func negativeTaxRateIsIgnoredRatherThanCreditingTax() {
        // The `taxRatePercent > 0` guard means a nonsense negative rate produces NO tax at all
        // (rather than a negative "credit"), so the total is just the discounted subtotal.
        let t = totals([(1000, true)], tax: -10)
        #expect(close(t.tax, 0))
        #expect(close(t.total, 1000))
    }

    @Test func zeroSubtotalProducesNoTaxDiscountOrDeposit() {
        // The `sub > 0` guard — no divide-by-zero, and every derived figure stays at zero.
        let t = totals([(0, true)], tax: 7.5,
                       discountType: .percentage, discountValue: 25,
                       depositType: .percentage, depositValue: 50)
        #expect(close(t.subtotal, 0))
        #expect(close(t.discount, 0))
        #expect(close(t.tax, 0))
        #expect(close(t.total, 0))
        #expect(close(t.deposit, 0))
    }

    // MARK: Discounts

    @Test func percentageDiscountReducesTaxProportionally() {
        // sub 2000 (1000 taxable), 25% discount → discounted 1500; tax = 1000 * (1500/2000) * 10%.
        let t = totals([(1000, true), (1000, false)], tax: 10,
                       discountType: .percentage, discountValue: 25)
        #expect(close(t.discount, 500))
        #expect(close(t.tax, 75))
        #expect(close(t.total, 1575))
    }

    @Test func hundredPercentDiscountZeroesTotalAndTax() {
        let t = totals([(1000, true)], tax: 7.5, discountType: .percentage, discountValue: 100)
        #expect(close(t.subtotal, 1000))
        #expect(close(t.discount, 1000))
        #expect(close(t.tax, 0))
        #expect(close(t.total, 0))
    }

    @Test func overOneHundredPercentDiscountIsClampedToTheSubtotal() {
        // A 150% discount can be typed. It is clamped to the money actually on the document, so the
        // totals card never prints a discount larger than the subtotal and the tax row never goes
        // negative — the total simply reaches $0.
        let t = totals([(1000, true)], tax: 10, discountType: .percentage, discountValue: 150)
        #expect(close(t.discount, 1000))
        #expect(t.discount <= t.subtotal)
        #expect(t.tax >= 0)
        #expect(close(t.total, 0))
    }

    @Test func fixedDiscountIsCappedAtSubtotal() {
        let t = totals([(50, false)], discountType: .fixed, discountValue: 100)
        #expect(close(t.discount, 50))   // capped at subtotal, not 100
        #expect(close(t.total, 0))       // clamped at zero, never negative

        // Over-discounting a TAXABLE line zeroes the tax row too — it is what the customer reads.
        let taxed = totals([(1000, true)], tax: 7.5, discountType: .fixed, discountValue: 5000)
        #expect(close(taxed.discount, 1000))
        #expect(close(taxed.tax, 0))
        #expect(close(taxed.total, 0))
    }

    @Test func negativeDiscountValueCannotMarkTheDocumentUp() {
        // A discount can only ever REMOVE money: a typo of -10% is clamped to $0 rather than
        // billing 10% more than the work, and the "Discount" row stays hidden (it needs > 0).
        let percentage = totals([(1000, false)], discountType: .percentage, discountValue: -10)
        #expect(close(percentage.discount, 0))
        #expect(close(percentage.total, 1000))
        let fixed = totals([(1000, false)], discountType: .fixed, discountValue: -250)
        #expect(close(fixed.discount, 0))
        #expect(close(fixed.total, 1000))
    }

    // MARK: The never-negative floor

    @Test func totalNeverGoesNegative() {
        let t = totals([(100, false), (-500, false)])   // a credit larger than the charge
        #expect(close(t.subtotal, -400))
        #expect(close(t.total, 0))
    }

    // MARK: Deposits

    @Test func percentageDepositOfTotal() {
        let t = totals([(200, false)], depositType: .percentage, depositValue: 25)
        #expect(close(t.deposit, 50))
    }

    @Test func depositIsClampedToTheTotalInBothShapes() {
        // No estimate can ask the customer for more than the job is worth, or for a negative amount.
        #expect(close(totals([(80, false)], depositType: .fixed, depositValue: 1000).deposit, 80))
        #expect(close(totals([(1000, false)], depositType: .percentage, depositValue: 200).deposit, 1000))
        for type in [AdjustmentType.percentage, .fixed] {
            #expect(close(totals([(1000, false)], depositType: type, depositValue: -25).deposit, 0))
        }
        // A 100% deposit is exactly the total — the boundary, not an over-ask.
        #expect(close(totals([(1000, false)], depositType: .percentage, depositValue: 100).deposit, 1000))
    }

    // MARK: Cent rounding + very large amounts

    @Test func centRoundingHoldsAcrossManyFractionalLines() {
        // 3 × $33.333 = $99.999 exactly — and every amount comes back already rounded to the cent
        // ONCE, so what the screen prints is the value itself: $100.00, not 99.999.
        let t = totals([(33.333, false), (33.333, false), (33.333, false)])
        #expect(t.subtotal == 100)
        #expect(t.total == 100)
        #expect(DomainMoney.wholeCents(t.total) == 10_000)
        #expect(t.exactTotal == Decimal(string: "99.999"), "the exact sum is kept for composition only")
    }

    @Test func centRoundingOnAPercentageDiscountOfAnOddSubtotal() {
        // $10.01 less 33%: the discount is exactly $3.3033 → $3.30; the total $6.7067 → $6.71.
        let t = totals([(10.01, false)], discountType: .percentage, discountValue: 33)
        #expect(t.discount == 3.30)
        #expect(t.total == 6.71)
        #expect(DomainMoney.wholeCents(t.total) == 671)
    }

    @Test func veryLargeAmountsStayExactToTheCent() {
        let t = totals([(9_999_999.99, true)], tax: 7.5)
        #expect(t.subtotal == 9_999_999.99)
        #expect(t.tax == 750_000)                // exactly 749,999.99925 → rounded once (half-up)
        #expect(t.total == 10_749_999.99)        // exactly 10,749,999.98925 → rounded once
        #expect(DomainMoney.wholeCents(t.total) == 1_074_999_999)   // fits an Int comfortably

        // A deposit on a very large total stays finite and exact too.
        let huge = totals([(1_000_000_000, true)], tax: 7.5, depositType: .percentage, depositValue: 10)
        #expect(huge.total.isFinite)
        #expect(close(huge.deposit, 107_500_000, eps: 1))
    }

    // MARK: - Zero Duplication: shared money core from GoldLifeDocuments

    /// Audit 2026-10-03 C27: My Business uses the shared money core from GoldLifeDocuments and
    /// defines no DomainMoney, InvoiceMath, ChangeOrderMath or EstimateTotals struct/enum type of
    /// its own.
    @Test func myBusinessDefinesNoDuplicateMoneyTypes() {
        let retiredDeclarations = [
            "enum DomainMoney", "enum InvoiceMath", "enum ChangeOrderMath", "struct EstimateTotals"
        ]
        var found: [String] = []
        for file in GLSource.codeFiles() {
            for declaration in retiredDeclarations {
                let name = declaration.split(separator: " ").last.map(String.init) ?? declaration
                let kind = declaration.split(separator: " ").first.map(String.init) ?? ""
                let pattern = "\\b\(kind)\\s+\(name)\\b"
                if file.text.range(of: pattern, options: .regularExpression) != nil {
                    found.append("\(file.path): \(declaration)")
                }
            }
        }
        #expect(found.isEmpty, "My Business still declares duplicate money types: \(found)")
    }
}
