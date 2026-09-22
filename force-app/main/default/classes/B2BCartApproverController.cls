/**
 * Controller for the B2B Cart Approver Picker LWC component.
 * Uses 'without sharing' so community users can query Users on
 * the same Account for approver selection.
 */
public without sharing class B2BCartApproverController {

    private static final Decimal DEFAULT_THRESHOLD = 5000;

    public class CartApprovalInfo {
        @AuraEnabled public Id cartId;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Id selectedApproverId;
        @AuraEnabled public List<ApproverOption> approvers;
        @AuraEnabled public Boolean needsApproval;
        @AuraEnabled public Decimal approvalThreshold;
    }

    public class ApproverOption {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;

        public ApproverOption(Id userId, String name, String email) {
            this.userId = userId;
            this.name = name;
            this.email = email;
        }
    }

    @AuraEnabled(cacheable=false)
    public static CartApprovalInfo getCartApprovalInfo() {
        CartApprovalInfo info = new CartApprovalInfo();
        info.approvers = new List<ApproverOption>();
        info.needsApproval = false;

        Id currentUserId = UserInfo.getUserId();

        List<WebCart> carts = [
            SELECT Id, GrandTotalAmount, Approval_Status__c, Selected_Approver__c,
                   AccountId, Status
            FROM WebCart
            WHERE OwnerId = :currentUserId
            AND Status != 'Closed'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (carts.isEmpty()) {
            return info;
        }

        WebCart cart = carts[0];
        info.cartId = cart.Id;
        info.grandTotal = cart.GrandTotalAmount != null ? cart.GrandTotalAmount : 0;
        info.approvalStatus = cart.Approval_Status__c != null ? cart.Approval_Status__c : 'Not Required';
        info.selectedApproverId = cart.Selected_Approver__c;

        // Separate query — WebCart.AccountId is polymorphic (Account, GuestBuyerProfile, User)
        Decimal threshold = DEFAULT_THRESHOLD;
        if (cart.AccountId != null) {
            List<Account> accts = [
                SELECT Approval_Threshold__c FROM Account WHERE Id = :cart.AccountId LIMIT 1
            ];
            if (!accts.isEmpty() && accts[0].Approval_Threshold__c != null) {
                threshold = accts[0].Approval_Threshold__c;
            }
        }
        info.approvalThreshold = threshold;
        info.needsApproval = info.grandTotal >= threshold;

        if (cart.AccountId == null) {
            return info;
        }

        List<User> users = [
            SELECT Id, Name, Email
            FROM User
            WHERE ContactId IN (
                SELECT Id FROM Contact WHERE AccountId = :cart.AccountId
            )
            AND IsActive = true
            AND Id != :currentUserId
            ORDER BY Name ASC
        ];

        for (User u : users) {
            info.approvers.add(new ApproverOption(u.Id, u.Name, u.Email));
        }

        return info;
    }

    @AuraEnabled
    public static String submitForApproval(Id cartId, Id approverId) {
        WebCart cart = new WebCart(
            Id = cartId,
            Selected_Approver__c = approverId
        );
        update cart;

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(cartId);

        // Separate query — WebCart.AccountId is polymorphic
        List<WebCart> cartDetails = [
            SELECT AccountId FROM WebCart WHERE Id = :cartId LIMIT 1
        ];
        Decimal threshold = DEFAULT_THRESHOLD;
        if (!cartDetails.isEmpty() && cartDetails[0].AccountId != null) {
            List<Account> accts = [
                SELECT Approval_Threshold__c FROM Account WHERE Id = :cartDetails[0].AccountId LIMIT 1
            ];
            if (!accts.isEmpty() && accts[0].Approval_Threshold__c != null) {
                threshold = accts[0].Approval_Threshold__c;
            }
        }
        req.setComments('Cart submitted for approval. Total exceeds $' + threshold.setScale(0).toPlainString() + ' threshold.');
        req.setNextApproverIds(new List<Id>{ approverId });

        Approval.ProcessResult result = Approval.process(req);

        if (result.isSuccess()) {
            return 'Cart submitted for approval successfully.';
        } else {
            throw new AuraHandledException(
                'Failed to submit for approval. Please try again or contact your administrator.'
            );
        }
    }
}
