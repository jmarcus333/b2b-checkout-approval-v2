import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingApprovals from '@salesforce/apex/B2BCartApprovalActionController.getPendingApprovals';
import processApproval from '@salesforce/apex/B2BCartApprovalActionController.processApproval';

export default class B2bCartApprovalAction extends LightningElement {
    @api recordId; // Kept for Experience Builder compatibility

    pendingApprovals = [];
    isLoading = true;
    isProcessing = false;
    comments = '';
    error;

    connectedCallback() {
        this.loadPendingApprovals();
    }

    async loadPendingApprovals() {
        this.isLoading = true;
        try {
            this.pendingApprovals = await getPendingApprovals();
        } catch (err) {
            this.error = err;
        } finally {
            this.isLoading = false;
        }
    }

    get hasPendingApprovals() {
        return this.pendingApprovals && this.pendingApprovals.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.hasPendingApprovals;
    }

    get approvalCards() {
        return this.pendingApprovals.map(pa => ({
            ...pa,
            formattedTotal: new Intl.NumberFormat('en-US', {
                style: 'currency',
                currency: 'USD'
            }).format(pa.grandTotal || 0),
            formattedDate: pa.submittedDate
                ? new Date(pa.submittedDate).toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                })
                : ''
        }));
    }

    handleCommentsChange(event) {
        const workItemId = event.target.dataset.id;
        // Store comments per work item
        this._commentsMap = this._commentsMap || {};
        this._commentsMap[workItemId] = event.target.value;
    }

    async handleApprove(event) {
        const workItemId = event.target.dataset.id;
        await this._processAction(workItemId, 'Approve');
    }

    async handleReject(event) {
        const workItemId = event.target.dataset.id;
        await this._processAction(workItemId, 'Reject');
    }

    async _processAction(workItemId, action) {
        this.isProcessing = true;
        const comments = (this._commentsMap && this._commentsMap[workItemId]) || '';

        try {
            const message = await processApproval({
                workItemId: workItemId,
                action: action,
                comments: comments
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: action === 'Approve' ? 'Approved' : 'Rejected',
                    message: message,
                    variant: action === 'Approve' ? 'success' : 'warning'
                })
            );

            // Reload to remove the processed item
            await this.loadPendingApprovals();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to process approval.',
                    variant: 'error'
                })
            );
        } finally {
            this.isProcessing = false;
        }
    }
}
