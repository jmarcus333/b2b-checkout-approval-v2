import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCartApprovalInfo from '@salesforce/apex/B2BCartApproverController.getCartApprovalInfo';
import submitForApproval from '@salesforce/apex/B2BCartApproverController.submitForApproval';

export default class B2bCartApproverPicker extends LightningElement {
    @api recordId; // Kept for Experience Builder compatibility but not used — cart is auto-detected
    cartId = null;
    approverOptions = [];
    selectedApproverId = '';
    isLoading = true;
    isSubmitting = false;
    grandTotal = 0;
    approvalStatus = '';
    currentApproverName = '';
    needsApproval = false;
    approvalThreshold = 5000;
    hasCart = false;
    error;

    connectedCallback() {
        this.loadCartInfo();
    }

    async loadCartInfo() {
        this.isLoading = true;
        try {
            const info = await getCartApprovalInfo();

            if (info && info.cartId) {
                this.hasCart = true;
                this.cartId = info.cartId;
                this.grandTotal = info.grandTotal || 0;
                this.approvalStatus = info.approvalStatus || 'Not Required';
                this.needsApproval = info.needsApproval;
                this.approvalThreshold = info.approvalThreshold || 5000;

                if (info.selectedApproverId) {
                    this.selectedApproverId = info.selectedApproverId;
                }

                if (info.approvers && info.approvers.length > 0) {
                    this.approverOptions = info.approvers.map(a => ({
                        label: a.name + (a.email ? ' (' + a.email + ')' : ''),
                        value: a.userId
                    }));

                    if (this.selectedApproverId) {
                        const match = info.approvers.find(a => a.userId === this.selectedApproverId);
                        if (match) {
                            this.currentApproverName = match.name;
                        }
                    }
                }
            }
        } catch (err) {
            this.error = err;
        } finally {
            this.isLoading = false;
        }
    }

    get showPicker() {
        return this.hasCart
            && this.needsApproval
            && this.approvalStatus !== 'Approved'
            && this.approvalStatus !== 'Pending Approval';
    }

    get hasApprovers() {
        return this.approverOptions.length > 0;
    }

    get showNoApproversMessage() {
        return !this.isLoading && !this.hasApprovers;
    }

    get isPending() {
        return this.hasCart && this.approvalStatus === 'Pending Approval';
    }

    get isApproved() {
        return this.hasCart && this.approvalStatus === 'Approved';
    }

    get isRejected() {
        return this.hasCart && this.approvalStatus === 'Rejected';
    }

    get statusMessage() {
        if (this.isPending) {
            return 'This cart is pending approval from ' + (this.currentApproverName || 'the selected approver') + '. You will be able to checkout once approved.';
        }
        if (this.isApproved) {
            return 'This cart has been approved. You may proceed to checkout.';
        }
        if (this.isRejected) {
            return 'Your approval request was rejected. Please select a new approver and resubmit.';
        }
        return '';
    }

    get formattedTotal() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD'
        }).format(this.grandTotal);
    }

    get formattedThreshold() {
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        }).format(this.approvalThreshold);
    }

    handleApproverChange(event) {
        this.selectedApproverId = event.detail.value;
    }

    async handleSubmitForApproval() {
        if (!this.selectedApproverId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Please select an approver',
                    message: 'Choose someone from your account to approve this cart.',
                    variant: 'warning'
                })
            );
            return;
        }

        this.isSubmitting = true;
        try {
            await submitForApproval({
                cartId: this.cartId,
                approverId: this.selectedApproverId
            });

            const match = this.approverOptions.find(o => o.value === this.selectedApproverId);
            if (match) {
                this.currentApproverName = match.label.split(' (')[0];
            }

            this.approvalStatus = 'Pending Approval';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Submitted for Approval',
                    message: 'Your cart has been submitted for approval. You will be notified once approved.',
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to submit for approval.',
                    variant: 'error'
                })
            );
        } finally {
            this.isSubmitting = false;
        }
    }
}
