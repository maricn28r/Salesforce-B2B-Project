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

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String searchTerm, String category) {
        String query = 'SELECT Id, Name, ProductCode, Family FROM Product2 ';
        List<String> conditions = new List<String>();

        if (String.isNotBlank(searchTerm)) {
            conditions.add('(Name LIKE :searchKey OR ProductCode LIKE :searchKey)');
        }
        if (String.isNotBlank(category)) {
            conditions.add('Family = :category');
        }
        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        query += ' ORDER BY Name LIMIT 50'; 
        String searchKey = String.isNotBlank(searchTerm) ? '%' + searchTerm + '%' : null;
        List<Product2> products = Database.query(query);
        List<ProductWrapper> results = new List<ProductWrapper>();
        for(Product2 p : products) {
            results.add(new ProductWrapper(p));
        }

        return results;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getProductCategories() {
        List<AggregateResult> results = [SELECT Family FROM Product2 WHERE Family != NULL GROUP BY Family ORDER BY Family];
        List<String> categories = new List<String>();
        for (AggregateResult ar : results) {
            String category = (String)ar.get('Family');
            if (category != null) {
                categories.add(category);
            }
        }
        return categories;
    }
}