@isTest
public with sharing class ProductSearchControllerTest {

    private static final String CATEGORY_ELECTRONICS = 'Electronics';
    private static final String CATEGORY_TOOLS = 'Tools';
    private static Id standardPricebookId;

    @testSetup
    static void makeData() {
        Id realStandardPricebookId = Test.getStandardPricebookId();
        standardPricebookId = realStandardPricebookId;
        
        List<Product2> products = new List<Product2>();
        products.add(new Product2(Name = 'Laptop Dell XPS 13', ProductCode = 'LX13-001', Family = CATEGORY_ELECTRONICS, IsActive = true));
        products.add(new Product2(Name = 'Wireless Mouse Logitech', ProductCode = 'MBL-XYZ', Family = CATEGORY_ELECTRONICS, IsActive = true));
        products.add(new Product2(Name = 'Bosch Impact Drill', ProductCode = 'WUB1', Family = CATEGORY_TOOLS, IsActive = true));
        products.add(new Product2(Name = 'Socket Wrench Set', ProductCode = 'ZK20', Family = CATEGORY_TOOLS, IsActive = true));
        products.add(new Product2(Name = 'Old Inactive Product', ProductCode = 'SNP', Family = CATEGORY_ELECTRONICS, IsActive = false)); 
        
        for (Integer i = 1; i <= 15; i++) {
            products.add(new Product2(Name = 'Test Product ' + i, ProductCode = 'PT' + i, Family = CATEGORY_ELECTRONICS, IsActive = true));
        }
        insert products;
        
        List<Product2> activeProducts = [SELECT Id FROM Product2 WHERE IsActive = TRUE AND ProductCode IN ('LX13-001', 'MBL-XYZ', 'WUB1', 'ZK20')];

        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : activeProducts) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = realStandardPricebookId, 
                Product2Id = p.Id,
                UnitPrice = 100.00, 
                IsActive = true
            ));
        }
        insert pbes; 
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract contract = new Contract(AccountId = acc.Id, Status = 'Draft', StartDate = Date.today());
        insert contract;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity', 
            StageName = 'Prospecting', 
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Pricebook2Id = realStandardPricebookId,
            ContractId = contract.Id 
        );
        insert opp;
    }

    @isTest
    static void testProductWrapperConstructor() {
        Product2 testProduct = [SELECT Id, Name, ProductCode, Family FROM Product2 WHERE ProductCode = 'LX13-001' LIMIT 1];
        
        Test.startTest();
        ProductSearchController.ProductWrapper wrapper = new ProductSearchController.ProductWrapper(testProduct);
        Test.stopTest();
        System.assertEquals(testProduct.Id, wrapper.id);
        System.assertEquals(testProduct.Name, wrapper.name);
        System.assertEquals(testProduct.ProductCode, wrapper.productCode);
        System.assertEquals(testProduct.Family, wrapper.family);
    }
    
    @isTest
    static void testSearchProducts_SearchByProductCode() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('XYZ', null, 0);
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('Wireless Mouse Logitech', results[0].name);
    }
    
    @isTest
    static void testSearchProducts_WithSearchTermAndCategory() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> results = ProductSearchController.searchProducts('Drill', CATEGORY_TOOLS, 0);
        Test.stopTest();
        System.assertEquals(1, results.size());
        System.assertEquals('Bosch Impact Drill', results[0].name);
    }

    @isTest
    static void testSearchProducts_Pagination() {
        Test.startTest();
        List<ProductSearchController.ProductWrapper> secondPage = ProductSearchController.searchProducts(null, null, 10);
        Test.stopTest();   
        System.assertEquals(9, secondPage.size());
    }

    @isTest
    static void testCountProducts_NoFilters() {
        Integer expectedCount = [SELECT COUNT() FROM Product2 WHERE IsActive = TRUE]; 
        Test.startTest();
        Integer count = ProductSearchController.countProducts(null, null);
        Test.stopTest();
        System.assertEquals(expectedCount, count);
    }

    @isTest
    static void testCountProducts_WithSearchTermAndCategory() {
        Test.startTest();
        Integer count = ProductSearchController.countProducts('Wrench', CATEGORY_TOOLS);
        Test.stopTest();
        System.assertEquals(1, count);
    }

    @isTest
    static void testGetProductCategories() {
        Test.startTest();
        Integer count = ProductSearchController.countProducts(null, null);
        Test.stopTest();
        
        System.assertEquals(expectedCount, count);
    }

    @isTest
    static void testCountProducts_WithSearchTermAndCategory() {
        Test.startTest();
        Integer count = ProductSearchController.countProducts('Wrench', CATEGORY_TOOLS);
        Test.stopTest();
        
        System.assertEquals(1, count);
    }
    
    @isTest
    static void testGetProductCategories() {
        Test.startTest();
        List<String> categories = ProductSearchController.getProductCategories();
        Test.stopTest();
        System.assertEquals(2, categories.size());
        System.assert(categories.contains(CATEGORY_ELECTRONICS));
        System.assert(categories.contains(CATEGORY_TOOLS));
        System.assertEquals(CATEGORY_ELECTRONICS, categories[0]);
    }

    @isTest
    static void testCreateOrderFromOpportunity_Success() {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
        Product2 prod1 = [SELECT Id FROM Product2 WHERE ProductCode = 'LX13-001' LIMIT 1];
        Product2 prod2 = [SELECT Id FROM Product2 WHERE ProductCode = 'MBL-XYZ' LIMIT 1];
        PricebookEntry pbe1 = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :prod1.Id AND Pricebook2Id = :opp.Pricebook2Id LIMIT 1];
    
        List<Map<String, Object>> selectedProducts = new List<Map<String, Object>>();
        selectedProducts.add(new Map<String, Object>{
            'productId' => prod1.Id, 
            'quantity' => 1.0
        });
        selectedProducts.add(new Map<String, Object>{
            'productId' => prod2.Id, 
            'quantity' => 2.0
        });
        
        Test.startTest();
        Order newOrder = ProductSearchController.createOrderFromOpportunity(opp.Id, selectedProducts);
        Test.stopTest();
        System.assertNotEquals(null, newOrder.Id);
        Order createdOrder = [SELECT Id, OpportunityId, AccountId, Status, Pricebook2Id, ContractId FROM Order WHERE Id = :newOrder.Id LIMIT 1];
        System.assertEquals(opp.Id, createdOrder.OpportunityId);
        List<OrderItem> orderItems = [SELECT Id, PricebookEntryId, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :newOrder.Id];
        System.assertEquals(2, orderItems.size());
        System.assertEquals(pbe1.UnitPrice, orderItems[0].UnitPrice);
    }

}