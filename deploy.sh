#!/bin/bash
#
# B2B Commerce Checkout Approval — Deployment Script
# ---------------------------------------------------
# Deploys all components to a target Salesforce org in the
# correct dependency order to avoid deployment failures.
#
# Usage:
#   ./deploy.sh <org-alias>
#
# Prerequisites:
#   - Salesforce CLI (sf) installed
#   - Target org authenticated (sf org login web -a <alias>)
#   - B2B Commerce enabled on target org
#

set -e

if [ -z "$1" ]; then
    echo ""
    echo "Usage: ./deploy.sh <org-alias>"
    echo ""
    echo "Example: ./deploy.sh my-sdo"
    echo ""
    exit 1
fi

ORG="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "================================================"
echo " B2B Commerce Checkout Approval — Deployer"
echo "================================================"
echo " Target org: $ORG"
echo ""

# ----------------------------
# Pre-flight: Verify org access
# ----------------------------
echo "[Pre-flight] Verifying org access..."
if ! sf org display --target-org "$ORG" --json > /dev/null 2>&1; then
    echo ""
    echo "  ERROR: Cannot connect to org '$ORG'."
    echo "  Please authenticate first: sf org login web -a $ORG"
    echo ""
    exit 1
fi
echo "  ✓ Org accessible"

# ----------------------------
# Pre-flight: Verify WebCart object exists (B2B Commerce required)
# ----------------------------
echo "[Pre-flight] Checking B2B Commerce is enabled..."
WEBCART_CHECK=$(sf data query --query "SELECT COUNT() FROM WebCart LIMIT 1" --target-org "$ORG" --json 2>&1 || true)
if echo "$WEBCART_CHECK" | grep -qi "sObject type 'WebCart' is not supported\|INVALID_TYPE\|doesn't exist"; then
    echo ""
    echo "  ERROR: WebCart object not found. B2B Commerce must be enabled on this org."
    echo "  Enable B2B Commerce in Setup before deploying."
    echo ""
    exit 1
fi
echo "  ✓ B2B Commerce enabled"
echo ""

# ----------------------------
# Phase 1: Custom Fields (must exist before Apex references them)
# ----------------------------
echo "[1/5] Deploying custom fields (Account + WebCart)..."
sf project deploy start \
    --source-dir force-app/main/default/objects/Account/fields \
    --source-dir force-app/main/default/objects/WebCart/fields \
    --target-org "$ORG" \
    --wait 10
echo "  ✓ Custom fields deployed"

# Brief pause for metadata propagation
sleep 5

# ----------------------------
# Phase 2: Apex Classes (depend on custom fields)
# ----------------------------
echo ""
echo "[2/5] Deploying Apex classes..."
sf project deploy start \
    --source-dir force-app/main/default/classes \
    --target-org "$ORG" \
    --wait 10
echo "  ✓ Apex classes deployed"

# ----------------------------
# Phase 3: LWC Components (depend on Apex classes)
# ----------------------------
echo ""
echo "[3/5] Deploying Lightning Web Components..."
sf project deploy start \
    --source-dir force-app/main/default/lwc \
    --target-org "$ORG" \
    --wait 10
echo "  ✓ LWC components deployed"

# ----------------------------
# Phase 4: Workflow Field Updates (must exist before approval process)
# ----------------------------
echo ""
echo "[4/5] Deploying Workflow Field Updates..."
sf project deploy start \
    --source-dir force-app/main/default/workflows \
    --target-org "$ORG" \
    --wait 10
echo "  ✓ Workflow field updates deployed"

# ----------------------------
# Phase 5: Approval Process + Flows (depend on fields + workflow)
# ----------------------------
echo ""
echo "[5/5] Deploying Approval Process and Flows..."
sf project deploy start \
    --source-dir force-app/main/default/approvalProcesses \
    --source-dir force-app/main/default/flows \
    --target-org "$ORG" \
    --wait 10
echo "  ✓ Approval process and flows deployed"

# ----------------------------
# Done!
# ----------------------------
echo ""
echo "================================================"
echo " Deployment Complete!"
echo "================================================"
echo ""
echo " POST-DEPLOYMENT STEPS (required):"
echo ""
echo "  1. FIELD-LEVEL SECURITY"
echo "     Grant profile/permission set access to:"
echo "       - WebCart: Approval_Status__c, Approval_Threshold__c, Selected_Approver__c"
echo "       - Account: Approval_Threshold__c"
echo ""
echo "  2. APEX CLASS ACCESS"
echo "     Grant Apex class access to community user profiles:"
echo "       - B2BCartApproverController"
echo "       - B2BCartApprovalActionController"
echo ""
echo "  3. ACTIVATE APPROVAL PROCESS"
echo "     Setup > Approval Processes > WebCart > B2B Checkout Approval > Activate"
echo ""
echo "  4. ACTIVATE FLOWS"
echo "     Setup > Flows > Activate each:"
echo "       - B2B Cart Approval Submit"
echo "       - B2B Cart Block Unapproved Checkout"
echo "       - B2B Cart Rejection Reset"
echo ""
echo "  5. ADD LWC TO EXPERIENCE SITE"
echo "     Experience Builder > Cart page > Add from Custom Components:"
echo "       - 'B2B Cart Approver Picker' (buyer-facing)"
echo "       - 'B2B Cart Approval Action' (approver-facing)"
echo "     Then Publish the site."
echo ""
echo "  6. SET ACCOUNT THRESHOLDS (optional)"
echo "     Edit 'Cart Approval Threshold' on Account records."
echo "     Default is \$5,000 if left blank."
echo ""
