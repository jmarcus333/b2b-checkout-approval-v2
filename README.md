# B2B Commerce Checkout Approval Workflow

A complete approval workflow for Salesforce B2B Commerce that requires buyer carts to be approved before checkout when the total exceeds a configurable threshold.

## Prerequisites

- Salesforce org with **B2B Commerce** enabled (standard on SDOs)
- Experience Cloud site for B2B Commerce storefront
- Salesforce CLI (`sf`) installed and authenticated

## Quick Deploy

```bash
# Clone this repo
git clone https://github.com/YOUR_GITHUB_USERNAME/b2b-checkout-approval.git
cd b2b-checkout-approval

# Authenticate to your org
sf org login web -a my-sdo

# Deploy (handles dependency order automatically)
bash deploy.sh my-sdo
```

## What's Included

| Component | Type | Description |
|-----------|------|-------------|
| **B2BCartApproverController** | Apex | Buyer-facing: finds cart, reads account threshold, lists approvers, submits |
| **B2BCartApprovalActionController** | Apex | Approver-facing: shows pending approvals, processes approve/reject |
| **b2bCartApproverPicker** | LWC | Buyer sees approval threshold, approver dropdown, and submit button |
| **b2bCartApprovalAction** | LWC | Approver sees pending carts with details, approve/reject buttons |
| **B2B Cart Approval Submit** | Flow | Auto-submits cart when checkout starts and threshold exceeded |
| **B2B Cart Block Unapproved Checkout** | Flow | Blocks checkout if approval pending or needed |
| **B2B Cart Rejection Reset** | Flow | Resets cart on rejection so buyer can resubmit |
| **B2B Checkout Approval** | Approval Process | Routes to buyer's selected approver |
| **WebCart.Approval_Status__c** | Picklist | Not Required / Pending / Approved / Rejected |
| **WebCart.Selected_Approver__c** | Lookup(User) | Approver chosen by the buyer |
| **WebCart.Approval_Threshold__c** | Currency | Threshold snapshot on cart |
| **Account.Approval_Threshold__c** | Currency | Per-account configurable threshold (default $5,000) |

## Post-Installation Setup

After deploying, complete these steps:

### 1. Field-Level Security
Grant profile/permission set access to:
- **WebCart**: Approval_Status__c, Approval_Threshold__c, Selected_Approver__c
- **Account**: Approval_Threshold__c

### 2. Apex Class Access
Grant community user profiles access to:
- B2BCartApproverController
- B2BCartApprovalActionController

### 3. Activate the Approval Process
Setup → Approval Processes → WebCart → **B2B Checkout Approval** → Activate

### 4. Activate the Flows
Setup → Flows → Activate each:
- B2B Cart Approval Submit
- B2B Cart Block Unapproved Checkout
- B2B Cart Rejection Reset

### 5. Add Components to Experience Site
In Experience Builder on the **Cart page**, add from Custom Components:
1. **B2B Cart Approver Picker** (buyer-facing)
2. **B2B Cart Approval Action** (approver-facing)

Then **Publish** the site.

### 6. Configure Account Thresholds (Optional)
Edit **Cart Approval Threshold** on Account records. Default is $5,000 if left blank.

## How It Works

1. Buyer's cart total exceeds the account's threshold → **Approver Picker** appears
2. Buyer selects a colleague from their account → submits for approval
3. Approver sees the request in the **Approval Action** component on the storefront
4. Approver approves → buyer can checkout. Rejects → cart resets, buyer can resubmit.

## Architecture Notes

- **`without sharing` Apex** — community users can query ProcessInstance and User records
- **Polymorphic AccountId** — WebCart.AccountId handled via separate Account query
- **Owner submitter type** — allows community users to submit their own carts for approval
- **Configurable thresholds** — per-Account field with $5,000 default fallback
- **No Chatter dependency** — notification-free for compatibility across orgs
- **All flows deploy as Draft** — activate manually to avoid conflicts with existing flows
- **API Version 60.0** — broad compatibility across SDOs
