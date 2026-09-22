/**
 * Controller for the B2B Cart Approval Action LWC component.
 * Allows community users (approvers) to view and act on pending
 * cart approval requests assigned to them.
 * Uses 'without sharing' so community users can query ProcessInstance records.
 */
public without sharing class B2BCartApprovalActionController {

    public class PendingApproval {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public Id cartId;
        @AuraEnabled public String cartName;
        @AuraEnabled public Decimal grandTotal;
        @AuraEnabled public String submitterName;
        @AuraEnabled public String accountName;
        @AuraEnabled public Datetime submittedDate;
        @AuraEnabled public String comments;
    }

    @AuraEnabled(cacheable=false)
    public static List<PendingApproval> getPendingApprovals() {
        Id currentUserId = UserInfo.getUserId();

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id,
                   ProcessInstance.TargetObjectId,
                   ProcessInstance.SubmittedById,
                   ProcessInstance.SubmittedBy.Name,
                   ProcessInstance.CreatedDate,
                   ProcessInstance.TargetObject.Name
            FROM ProcessInstanceWorkitem
            WHERE ActorId = :currentUserId
            AND ProcessInstance.Status = 'Pending'
            AND ProcessInstance.TargetObject.Type = 'WebCart'
        ];

        if (workItems.isEmpty()) {
            return new List<PendingApproval>();
        }

        Set<Id> cartIds = new Set<Id>();
        for (ProcessInstanceWorkitem wi : workItems) {
            cartIds.add(wi.ProcessInstance.TargetObjectId);
        }

        Map<Id, WebCart> carts = new Map<Id, WebCart>([
            SELECT Id, Name, GrandTotalAmount, Account.Name
            FROM WebCart
            WHERE Id IN :cartIds
        ]);

        Map<Id, String> commentsMap = new Map<Id, String>();
        List<ProcessInstanceStep> steps = [
            SELECT ProcessInstanceId, Comments
            FROM ProcessInstanceStep
            WHERE ProcessInstanceId IN (
                SELECT ProcessInstanceId FROM ProcessInstanceWorkitem WHERE Id IN :workItems
            )
            AND Comments != null
            ORDER BY CreatedDate DESC
        ];
        for (ProcessInstanceStep step : steps) {
            if (!commentsMap.containsKey(step.ProcessInstanceId)) {
                commentsMap.put(step.ProcessInstanceId, step.Comments);
            }
        }

        List<PendingApproval> result = new List<PendingApproval>();
        for (ProcessInstanceWorkitem wi : workItems) {
            PendingApproval pa = new PendingApproval();
            pa.workItemId = wi.Id;
            pa.cartId = wi.ProcessInstance.TargetObjectId;
            pa.submitterName = wi.ProcessInstance.SubmittedBy.Name;
            pa.submittedDate = wi.ProcessInstance.CreatedDate;
            pa.comments = commentsMap.get(wi.ProcessInstanceId);

            WebCart cart = carts.get(pa.cartId);
            if (cart != null) {
                pa.cartName = cart.Name;
                pa.grandTotal = cart.GrandTotalAmount;
                pa.accountName = cart.Account != null ? cart.Account.Name : '';
            }

            result.add(pa);
        }

        return result;
    }

    @AuraEnabled
    public static String processApproval(Id workItemId, String action, String comments) {
        Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
        req.setWorkitemId(workItemId);
        req.setAction(action);

        if (String.isNotBlank(comments)) {
            req.setComments(comments);
        }

        Approval.ProcessResult result = Approval.process(req);

        if (result.isSuccess()) {
            return action == 'Approve'
                ? 'Cart approved successfully.'
                : 'Cart rejected.';
        } else {
            throw new AuraHandledException(
                'Failed to process approval. Please try again or contact your administrator.'
            );
        }
    }
}
