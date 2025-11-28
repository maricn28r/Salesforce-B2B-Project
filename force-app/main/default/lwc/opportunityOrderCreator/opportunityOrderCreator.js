import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import searchProducts from '@salesforce/apex/ProductSearchController.searchProducts';
import getProductCategories from '@salesforce/apex/ProductSearchController.getProductCategories';

const COLUMNS = [
    { label: 'Product Name', fieldName: 'name', type: 'text' },
    { label: 'Code', fieldName: 'productCode', type: 'text' },
    { label: 'Category', fieldName: 'family', type: 'text' }
];

export default class OpportunityOrderCreator extends LightningElement {
    searchTerm = '';
    selectedCategory = '';
    @track productCategories = []; 
    @track productList = [];
    columns = COLUMNS;
    isLoading = false;

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
        this.isLoading = true;
        searchProducts({ searchTerm: this.searchTerm, category: this.selectedCategory })
            .then(result => {
                this.productList = result;
                this.isLoading = false;
                if (result.length === 0) {
                    this.showToast('Search Info', 'No products found matching the criteria.', 'info');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error searching products: ' + error.body.message, 'error');
                console.error('Error searching products:', error);
                this.isLoading = false;
            });
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
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
}