@isTest
private class TestClassTest {

    @isTest
    static void myUnitTest() {
        Integer expected = 1;
        Integer actual = 1;
        Assert.areEqual(expected, actual)
    }
}