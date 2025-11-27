import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

const PERSON_FIELDS = [
    'Lead.FirstName', 
    'Lead.LastName', 
    'Lead.Salutation', 
    'Lead.Title', 
    'Lead.Email', 
    'Lead.Phone',
    'Lead.MobilePhone',
    'Lead.GenderIdentity',
    'Lead.Pronouns'
];

const COMPANY_FIELDS = [
    'Lead.Company', 
    'Lead.Website', 
    'Lead.Industry', 
    'Lead.Company_Growth_Status__c',
    'Lead.AnnualRevenue', 
    'Lead.NumberOfEmployees', 
    'Lead.NumberofLocations__c',
    'Lead.Publicly_Traded__c',
    'Lead.SICCode__c'
];

const SYSTEM_FIELDS = [
    'Lead.Status',
    'Lead.Rating',
    'Lead.CreatedDate', 
    'Lead.LastModifiedDate', 
    'Lead.ProductInterest__c',
    'Lead.Primary__c',
    'Lead.Id', 
    'Lead.OwnerId',
    'Lead.Target_Date__c'
];

const ALL_FIELDS = [...PERSON_FIELDS, ...COMPANY_FIELDS, ...SYSTEM_FIELDS, 'Lead.Name'];
const formatLabel = (apiPart) => {
    let label = apiPart.replace(/_c$/, '');
    label = label.replace(/([A-Z])/g, ' $1');
    label = label.replace(/_+/g, ' '); 
    label = label.replace(/\s{2,}/g, ' ').trim(); 
    return label.charAt(0).toUpperCase() + label.slice(1);
};

export default class LeadDetailsTabs extends LightningElement {
    @api recordId;

    @wire(getRecord, { recordId: '$recordId', fields: ALL_FIELDS })
    lead;
    formatFieldValue(fieldApi, value) {
        if (!value) return '';
        if (fieldApi.toLowerCase().includes('date')) {
            const date = new Date(value);
            return date.toLocaleDateString('pl-PL');
        }
        if (fieldApi.toLowerCase().includes('email')) {
            return { type: 'link', href: `mailto:${value}`, label: value };
        }
        if (fieldApi.toLowerCase().includes('phone')) {
            const clean = value.replace(/\D/g, '');
            let formatted = clean.replace(/(\d{3})(?=\d)/g, '$1-');
            formatted = formatted.endsWith('-') ? formatted.slice(0, -1) : formatted;
            return { type: 'link', href: `tel:${clean}`, label: formatted };
        }
        if (fieldApi.toLowerCase().includes('website')) {
            const url = value.startsWith('http') ? value : `https://${value}`;
            return { type: 'link', href: url, label: value };
        }
        return value;
    }
    mapFields(fields) {
        if (!this.lead.data) return [];
        return fields.map(field => {
            const value = getFieldValue(this.lead.data, field);
            const formattedValue = this.formatFieldValue(field, value);
            return {
                label: formatLabel(field.split('.')[1]),
                value: formattedValue
            };
        });
    }
    get personData() { return this.mapFields(PERSON_FIELDS); }
    get companyData() { return this.mapFields(COMPANY_FIELDS); }
    get systemData() { return this.mapFields(SYSTEM_FIELDS); }
    get leadName() { return getFieldValue(this.lead.data, 'Lead.Name'); }
    get leadStatus() { return getFieldValue(this.lead.data, 'Lead.Status'); }
    get leadRating() { return getFieldValue(this.lead.data, 'Lead.Rating'); }
    get leadCompany() { return getFieldValue(this.lead.data, 'Lead.Company'); }
    get isLoading() { return !this.lead.data && !this.lead.error; }
}