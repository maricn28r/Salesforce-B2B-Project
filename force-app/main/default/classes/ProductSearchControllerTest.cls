@isTest
private class ProductSearchControllerTest {
    private static final String CAT_A = 'Construction';
    private static final String CAT_B = 'Electrical';
    
    @TestSetup
    static void setupTestData() {
        Account testAcc = new Account(Name = 'Test Account');
        insert testAcc;
        List<Product2> products = new List<Product2>{
            new Product2(
                Name = 'Heavy Duty Crane', 
                ProductCode = 'CRANE-HD', 
                Family = CAT_A,
                IsActive = true
            ),
            new Product2(
                Name = 'Water Pump', 
                ProductCode = 'PUMP-01', 
                Family = CAT_B,
                IsActive = true
            ),
            new Product2(
                Name = 'Old Heater', 
                ProductCode = 'HEAT-01', 
                Family = CAT_A,
                IsActive = false
            ),
            new Product2(
                Name = 'Concrete Mixer', 
                ProductCode = 'MIX-01', 
                Family = CAT_A,
                IsActive = true
            )
        };
        insert products;
    }

    @isTest 
    static void testSearchByTerm() {
        
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('Crane', null);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should find exactly one product (Crane).');
        System.assertEquals('Heavy Duty Crane', results[0].name, 'Product name should match.');
    }
    
    @isTest 
    static void testSearchByCategory() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts(null, CAT_B);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should find only one product from the Electrical category.');
        System.assertEquals('Water Pump', results[0].name);
    }

    @isTest 
    static void testSearchCombined() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('Mixer', CAT_A);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should find one product after combined filtering.');
    }
    
    @isTest
    static void testGetUniqueCategories() {
        
        Test.startTest();
        List<String> categories = ProductSearchController.getProductCategories();
        Test.stopTest();

        System.assertEquals(2, categories.size(), 'Should return two unique categories.');
        System.assert(categories.contains(CAT_A), 'Collection should contain Construction category.');
        System.assert(categories.contains(CAT_B), 'Collection should contain Electrical category.');
    }
}