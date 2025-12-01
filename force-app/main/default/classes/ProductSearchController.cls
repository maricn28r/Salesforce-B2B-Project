public with sharing class ProductSearchController {
    public class ProductWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String productCode;
        @AuraEnabled public String family;

        public ProductWrapper(Product2 p) {
            this.id = p.Id;
            this.name = p.Name;
            this.productCode = p.ProductCode;
            this.family = p.Family;
        }
    }

    private static final Integer PAGE_SIZE = 10;

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String searchTerm, String category, Integer offset) {
        String query = 'SELECT Id, Name, ProductCode, Family FROM Product2 ';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(searchTerm)) {
            conditions.add('(Name LIKE :searchKey OR ProductCode LIKE :searchKey)');
        }
        if (String.isNotBlank(category)) {
            conditions.add('Family = :category');
        }
        
        conditions.add('IsActive = true'); 
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        query += ' ORDER BY Name LIMIT :PAGE_SIZE OFFSET :offset'; 
        String searchKey = String.isNotBlank(searchTerm) ? '%' + searchTerm + '%' : null;
        List<Product2> products = Database.query(query);
        List<ProductWrapper> results = new List<ProductWrapper>();
        
        for(Product2 p : products) {
            results.add(new ProductWrapper(p));
        }

        return results;
    }

    @AuraEnabled(cacheable=true)
    public static Integer countProducts(String searchTerm, String category) {
        String query = 'SELECT count() FROM Product2 ';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(searchTerm)) {
            conditions.add('(Name LIKE :searchKey OR ProductCode LIKE :searchKey)');
        }
        if (String.isNotBlank(category)) {
            conditions.add('Family = :category');
        }
        conditions.add('IsActive = true'); 

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        String searchKey = String.isNotBlank(searchTerm) ? '%' + searchTerm + '%' : null;
        return Database.countQuery(query);
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        List<AggregateResult> results = [ 
            SELECT Family 
            FROM Product2 
            WHERE Family != NULL 
            GROUP BY Family 
            ORDER BY Family
            ];
        List<String> categories = new List<String>();
        for (AggregateResult ar : results) {
            String category = (String)ar.get('Family');
            if (category != null) {
                categories.add(category);
            }
        }
        return categories;
    }

    @AuraEnabled
    public static Order createOrderFromOpportunity(String opportunityId, List<Map<String, Object>> selectedProducts) {
        Opportunity opp = [
            SELECT AccountId, Pricebook2Id, ContractId, Pricebook2.Name 
            FROM Opportunity 
            WHERE Id = :opportunityId 
            LIMIT 1
        ];
        
        if (opp.AccountId == null) {
            throw new AuraHandledException('Opportunity must be linked to an Account.');
        }
        Order newOrder = new Order(
            OpportunityId = opportunityId,
            AccountId = opp.AccountId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = opp.Pricebook2Id,
            ContractId = opp.ContractId 
        );
        insert newOrder;

        List<OrderItem> orderItems = new List<OrderItem>();
        Set<Id> productIds = new Set<Id>();
        for (Map<String, Object> productMap : selectedProducts) {
            productIds.add((String)productMap.get('productId'));
        }
        
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>();
        for(PricebookEntry pbe : [  
                SELECT Id, Product2Id, UnitPrice 
                FROM PricebookEntry 
                WHERE Product2Id IN :productIds 
                AND Pricebook2Id = :opp.Pricebook2Id 
                AND IsActive = TRUE]) {
            pbeMap.put(pbe.Product2Id, pbe);
        }

        for (Map<String, Object> productMap : selectedProducts) {
            String productId = (String)productMap.get('productId');
            if (pbeMap.containsKey(productId)) {
                PricebookEntry pbe = pbeMap.get(productId);
                Decimal quantity = (Decimal)productMap.get('quantity');
                orderItems.add(new OrderItem(
                    OrderId = newOrder.Id,
                    PricebookEntryId = pbe.Id,
                    Quantity = quantity,
                    UnitPrice = pbe.UnitPrice 
                ));
            }
        }
        
        if (!orderItems.isEmpty()) {
            insert orderItems;
        }
        
        return [SELECT Id, OrderNumber FROM Order WHERE Id = :newOrder.Id LIMIT 1]; 
    }
}