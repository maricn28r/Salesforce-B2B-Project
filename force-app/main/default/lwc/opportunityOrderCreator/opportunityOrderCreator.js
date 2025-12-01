import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import searchProducts from '@salesforce/apex/ProductSearchController.searchProducts';
import getProductCategories from '@salesforce/apex/ProductSearchController.getProductCategories';
import countProducts from '@salesforce/apex/ProductSearchController.countProducts';
import createOrderFromOpportunity from '@salesforce/apex/ProductSearchController.createOrderFromOpportunity';

const COLUMNS = [
    { label: 'Product Name', fieldName: 'name', type: 'text' },
    { label: 'Code', fieldName: 'productCode', type: 'text' },
    { label: 'Category', fieldName: 'family', type: 'text' },
    { label: 'Quantity', fieldName: 'quantity', type: 'number', editable: true }
];

export default class OpportunityOrderCreator extends LightningElement {
    @api recordId;
    isSearching = true;
    isReviewing = false; 
    isLoading = false; 
    pageNumber = 1;
    pageSize = 10; 
    totalRecords = 0;
    totalPages = 0;
    columns = COLUMNS;
    searchTerm = '';
    selectedCategory = '';
    @track productList = [];
    @track selectedProducts = []; 
    selectedProductMap = new Map();
    productCategories;

    @wire(getProductCategories)
    wiredCategories({ error, data }) {
        if (data) {
            this.productCategories = [{ label: 'All Categories', value: '' }];
            data.forEach(category => {
                this.productCategories.push({
                    label: category,
                    value: category
                });
            });
        } else if (error) {
            this.showToast('Error', 'Error loading categories: ' + error.body.message, 'error');
            console.error('Error loading categories:', error);
        }
    }

    handleSearch() {
        this.pageNumber = 1;
        this.isLoading = true;

        countProducts({ searchTerm: this.searchTerm, category: this.selectedCategory })
            .then(total => {
                this.totalRecords = total;
                this.totalPages = Math.ceil(total / this.pageSize);
                this.loadProducts();
            })
        }

    handleSearch() {
        this.pageNumber = 1;
        this.isLoading = true;

        countProducts({ searchTerm: this.searchTerm, category: this.selectedCategory })
            .then(total => {
                this.totalRecords = total;
                this.totalPages = Math.ceil(total / this.pageSize);
                this.loadProducts();
            })
            .catch(error => {
                this.showToast('Error', 'Error counting products: ' + error.body.message, 'error');
                console.error('Error counting products:', error);
                this.isLoading = false;
            });
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.loadProducts();
        }
    }
    
    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.loadProducts();
        }
    }
    
    saveDraftValues() {
        const datatable = this.template.querySelector('lightning-datatable');
        if (!datatable) return;

        const draftValues = datatable.draftValues; 

        if (draftValues && draftValues.length > 0) {
            this.handleCellChange({ detail: { draftValues: draftValues } });
        }
    }

    handleBackToSearch() {
        this.isSearching = true;
        this.isReviewing = false;
        this.loadProducts(); 
    }
    
    handleCreateOrder() {
        this.isLoading = true;
        const productsForApex = this.selectedProducts.map(p => ({
            productId: p.productId,
            quantity: p.quantity
        }));

        createOrderFromOpportunity({ 
            opportunityId: this.recordId, 
            selectedProducts: productsForApex 
        })
        .then(order => {
            this.showToast('Success', 'Order ' + order.OrderNumber + ' created successfully!', 'success');
            this.handleClose(); 
        })
        .catch(error => {
            let errorMessage = error.body && error.body.message ? error.body.message : 'Unknown error';
            this.showToast('Error', 'Error creating Order: ' + errorMessage, 'error');
            console.error('Error creating Order:', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        this.handleSearch();
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.handleSearch();
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get isFirstPage() {
        return this.pageNumber === 1;
    }

    get isLastPage() {
        return this.pageNumber >= this.totalPages || this.totalRecords === 0;
    }
    
    updateSelectedProductsList() {
        this.selectedProducts = Array.from(this.selectedProductMap.values());
    }

    loadProducts() {
        this.isLoading = true;
        let offset = (this.pageNumber - 1) * this.pageSize;

        searchProducts({ searchTerm: this.searchTerm, category: this.selectedCategory, offset: offset })
            .then(result => {
                this.productList = result.map(item => {
                    const existingItem = this.selectedProductMap.get(item.id);
                    let quantity = existingItem ? existingItem.quantity : 1; 
                    return {...item, quantity: quantity};
                });
                this.isLoading = false;
                this.setInitialSelection();
                if (result.length === 0 && this.pageNumber === 1) {
                    this.showToast('Search Info', 'No products found matching the criteria.', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error loading products: ' + error.body.message, 'error');
                console.error('Error loading products:', error);
                this.isLoading = false;
            });
    }

    setInitialSelection() {
        const selectedIds = this.productList
            .filter(item => this.selectedProductMap.has(item.id))
            .map(item => item.id);
            
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = selectedIds;
        }
    }

    handleRowSelection(event) {
        const datatable = this.template.querySelector('lightning-datatable');
        if (!datatable) return;

        const selectedRows = datatable.getSelectedRows();
        const selectedIdsOnPage = new Set(selectedRows.map(row => row.id));

        this.productList.forEach(item => {
            if (this.selectedProductMap.has(item.id) && !selectedIdsOnPage.has(item.id)) {
                this.selectedProductMap.delete(item.id);
            }
        });

        selectedRows.forEach(item => {
            if (!this.selectedProductMap.has(item.id)) {
                this.selectedProductMap.set(item.id, {
                    productId: item.id,
                    name: item.name,
                    productCode: item.productCode,
                    quantity: item.quantity && item.quantity > 0 ? item.quantity : 1 
                });
            }
        });
        
        this.updateSelectedProductsList();
    }

    handleNextStep() {
        this.saveDraftValues();
        
        this.updateSelectedProductsList(); 

        if (this.selectedProducts.length === 0) {
            this.showToast('Warning', 'Select at least one product to create an Order.', 'warning');
            return;
        }

        this.selectedProducts = this.selectedProducts.map(item => {
            let quantity = item.quantity && item.quantity > 0 ? item.quantity : 1;
            if (quantity <= 0) {
                this.showToast('Warning', 'Quantity for ' + item.name + ' must be greater than 0. Using 1.', 'warning');
                quantity = 1;
            }
            return {...item, quantity: quantity};
        });

        this.isSearching = false;
        this.isReviewing = true;
    }
    
    handleQuantityChange(event) {
        const { name: productId, value: newQuantity } = event.target;
        const item = this.selectedProductMap.get(productId);
        if (item) {
            item.quantity = Math.max(1, parseInt(newQuantity) || 1);
            this.updateSelectedProductsList(); 
        }
    }
    
    handleRemoveItem(event) {
        const productIdToRemove = event.target.name;
        this.selectedProductMap.delete(productIdToRemove);
        this.updateSelectedProductsList();
        
        if (this.selectedProducts.length === 0) {
            this.handleBackToSearch();
        } else {
            this.setInitialSelection();
        }
    }
    
    handleCellChange(event) {
        const datatable = this.template.querySelector('lightning-datatable');
        const draftValues = event.detail.draftValues;
        const updatedProductList = JSON.parse(JSON.stringify(this.productList));
        
        draftValues.forEach(draft => {
            const productId = draft.id;
            const newQuantity = parseFloat(draft.quantity);
            const index = updatedProductList.findIndex(item => item.id === productId);
            
            if (index !== -1) {
                updatedProductList[index].quantity = Math.max(1, newQuantity || 1);
            }
            const mapItem = this.selectedProductMap.get(productId);
            if (mapItem) {
                mapItem.quantity = Math.max(1, newQuantity || 1);
                this.updateSelectedProductsList();
            }
        });
        
        this.productList = updatedProductList;
        datatable.draftValues = [];
    }
}