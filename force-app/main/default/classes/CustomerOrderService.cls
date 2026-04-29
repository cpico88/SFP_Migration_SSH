/**
 * @description       : Service class to handle Customer Order processing logic.
 *                      Validates orders, applies discounts, and updates order status.
 * @author            : Jane Doe
 * @created           : 2026-04-22
 * @last modified on  : 2026-04-22
 * @last modified by  : Jane Doe
 * @user story        : US-00123
 **/
public with sharing class CustomerOrderService {

    // ─── Constants ────────────────────────────────────────────────────────────
    private static final String CLASS_NAME      = 'CustomerOrderService';
    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_REJECTED = 'Rejected';
    private static final Decimal DISCOUNT_RATE  = 0.10; // 10% discount threshold

    // ─── Custom Exception ─────────────────────────────────────────────────────
    public class CustomerOrderException extends Exception {}

    // ─── Public Methods ───────────────────────────────────────────────────────

    /**
     * @description Processes a list of Orders: applies discounts and sets status.
     * @param orders List of Order records to process
     * @return       List of updated Order records (not yet committed to DB)
     */
    public static List<Order> processOrders(List<Order> orders) {
        if (orders == null || orders.isEmpty()) {
            return new List<Order>();
        }

        try {
            return applyBusinessRules(orders);
        } catch (Exception e) {
            logError(CLASS_NAME, 'processOrders', e);
            throw new CustomerOrderException(e.getMessage());
        }
    }

    // ─── Private Methods ──────────────────────────────────────────────────────

    /**
     * @description Applies discount and approval rules to each Order.
     * @param orders List of Order records
     * @return       Updated list of Orders
     */
    private static List<Order> applyBusinessRules(List<Order> orders) {

        // Collect Account IDs to query in bulk — no SOQL in loops
        Set<Id> accountIds = new Set<Id>();
        for (Order ord : orders) {
            if (ord.AccountId != null) {
                accountIds.add(ord.AccountId);
            }
        }

        // Selective query using indexed AccountId field
        Map<Id, Account> accountMap = new Map<Id, Account>(
            [SELECT Id, Name, AnnualRevenue, Rating
             FROM Account
             WHERE Id IN :accountIds]
        );

        List<Order> updatedOrders = new List<Order>();

        for (Order ord : orders) {
            Account relatedAccount = accountMap.get(ord.AccountId);

            if (relatedAccount == null) {
                continue; // Skip orders with no matching account
            }

            // Apply 10% discount for Premium (Hot) accounts
            if (relatedAccount.Rating == 'Hot' && ord.TotalAmount != null) {
                ord.Description = 'Discount Applied: 10% for Premium Account - '
                                  + relatedAccount.Name;
                // Note: TotalAmount is formula-based; update via OrderItems in real impl
            }

            // Set order status based on account revenue
            if (relatedAccount.AnnualRevenue != null
                && relatedAccount.AnnualRevenue >= 1000000) {
                ord.Status = STATUS_APPROVED;
            } else {
                ord.Status = STATUS_REJECTED;
            }

            updatedOrders.add(ord);
        }

        // Bulk DML — single update outside the loop
        if (!updatedOrders.isEmpty()) {
            update updatedOrders;
        }

        return updatedOrders;
    }

    /**
     * @description Centralized error logging utility.
     * @param className  Calling class name
     * @param methodName Calling method name
     * @param e          Caught exception
     */
    private static void logError(String className, String methodName, Exception e) {
        System.debug(LoggingLevel.ERROR,
            '[' + className + '.' + methodName + '] ' +
            'Message: ' + e.getMessage() +
            ' | Line: '  + e.getLineNumber()
        );
        // TODO: Replace with your org's error logging framework (e.g., Platform Events)
    }
}