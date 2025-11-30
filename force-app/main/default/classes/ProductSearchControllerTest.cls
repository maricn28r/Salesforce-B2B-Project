@isTest
private class ProductSearchControllerTest {
    private static final String CAT_A = 'Construction';
    private static final String CAT_B = 'Electrical';
    private static Id standardPricebookId = Test.getStandardPricebookId();

    @TestSetup
    static void setupTestData() {
        Account testAcc = new Account(Name = 'Test Account for Order');
        insert testAcc;

        Contract testContract = new Contract(
            AccountId = testAcc.Id,
            StartDate = Date.today().addDays(-10),
            Status = 'Activated',
            ContractTerm = 12
        );
        insert testContract;
        
        Opportunity testOpp = new Opportunity(
            Name = 'Order Test Opportunity',
            AccountId = testAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId,
            ContractId = testContract.Id 
        );
        insert testOpp;
        
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
        
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : products) {
            if (p.IsActive) {
                pbes.add(new PricebookEntry(
                    Pricebook2Id = standardPricebookId,
                    Product2Id = p.Id,
                    UnitPrice = 1000.00,
                    IsActive = true
                ));
            }
        }
        insert pbes;
    }

    @isTest 
    static void testSearchByTerm() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('Crane', null, 0);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Should find exactly one active product (Crane).');
        System.assertEquals('Heavy Duty Crane', results[0].name, 'Product name should match.');
    }
    
    @isTest 
    static void testSearchByCategory() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts(null, CAT_B, 0);
        Test.stopTest(); 
        System.assertEquals(1, results.size(), 'Should find only one active product from the Electrical category.');
        System.assertEquals('Water Pump', results[0].name);
    }

    @isTest 
    static void testSearchIgnoresInactiveProducts() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('Heater', CAT_A, 0);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should not return inactive products.');
    }

    @isTest
    static void testSearchWithOffset() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts(null, null, 2);
        Test.stopTest();
        System.assertEquals(1, results.size(), 'Offset 2 should return only the last of 3 active products.');
        System.assertEquals('Water Pump', results[0].name, 'Should return the last element after sorting and offset.');
    }
    
    @isTest
    static void testCountProductsTotal() {
        Test.startTest();
        Integer totalCount = ProductSearchController.countProducts(null, null);
        Test.stopTest();
        System.assertEquals(3, totalCount, 'Should count only 3 active products.');
    }

    @isTest
    static void testCountProductsByCategory() {
        Test.startTest();
        Integer catACount = ProductSearchController.countProducts(null, CAT_A);
        Test.stopTest();
        System.assertEquals(2, catACount, 'Should count 2 active products in the Construction category.');
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

    @isTest
    static void testCreateOrderFromOpportunitySuccess() {
        Opportunity testOpp = [SELECT Id, AccountId, ContractId FROM Opportunity LIMIT 1];
        List<Product2> products = [SELECT Id FROM Product2 WHERE IsActive = TRUE];
        List<Map<String, Object>> selectedProducts = new List<Map<String, Object>>();
        selectedProducts.add(new Map<String, Object>{
            'productId' => products[0].Id, 
            'quantity' => 2.0
        });
        selectedProducts.add(new Map<String, Object>{
            'productId' => products[1].Id, 
            'quantity' => 1.5
        });
        
        Test.startTest();
        Order newOrder = ProductSearchController.createOrderFromOpportunity(testOpp.Id, selectedProducts);
        Test.stopTest();
        System.assertNotEquals(null, newOrder, 'Order should be created.');
        
        Order createdOrder = [SELECT Id, OpportunityId, AccountId, Status, ContractId, EffectiveDate
                              FROM Order 
                              WHERE Id = :newOrder.Id];
                              
        System.assertEquals(testOpp.Id, createdOrder.OpportunityId, 'Order should be linked to Opportunity.');
        System.assertEquals(testOpp.AccountId, createdOrder.AccountId, 'Order should be linked to Account.');
        System.assertEquals('Draft', createdOrder.Status, 'Status should be set to Draft.');
        System.assertEquals(Date.today(), createdOrder.EffectiveDate, 'EffectiveDate should be set to today (Order Start Date).');
        System.assertEquals(testOpp.ContractId, createdOrder.ContractId, 'ContractId should be copied from Opportunity (Contract Number).');
        List<OrderItem> createdOrderItems = [SELECT Id, Quantity 
                                             FROM OrderItem 
                                             WHERE OrderId = :newOrder.Id];
        System.assertEquals(2, createdOrderItems.size(), '2 OrderItems should be created.');
        System.assertEquals(2.0, createdOrderItems[0].Quantity, 'Quantity of the first OrderItem should be 2.0');
        System.assertEquals(1.5, createdOrderItems[1].Quantity, 'Quantity of the second OrderItem should be 1.5');
    }

    @isTest
    static void testCreateOrderWithoutAccountFails() {
        Account acc = new Account(Name = 'No Contact Account');
        insert acc;
        Opportunity oppWithoutAccount = new Opportunity(
            Name = 'No Account Test',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPricebookId
        );
        insert oppWithoutAccount;
        
        List<Map<String, Object>> selectedProducts = new List<Map<String, Object>>();
        selectedProducts.add(new Map<String, Object>{
            'productId' => [SELECT Id FROM Product2 LIMIT 1][0].Id, 
            'quantity' => 1.0
        });

        Test.startTest();
        Boolean caughtException = false;
        try {
            ProductSearchController.createOrderFromOpportunity(oppWithoutAccount.Id, selectedProducts);
        } catch (AuraHandledException e) {
            caughtException = true;
            System.assertEquals('Opportunity must be linked to an Account.', e.getMessage(), 'Should throw error when AccountId is missing.');
        } catch (Exception e) {
             System.assert(false, 'Caught unexpected exception: ' + e.getTypeName());
        }
        Test.stopTest();
        System.assert(caughtException, 'An AuraHandledException should be thrown.');
    }
}