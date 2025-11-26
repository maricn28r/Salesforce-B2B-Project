@isTest
private class TestClassTest {

    @isTest
    static void myUnitTest() {
        Integer expected = 1;
        Integer actual = 12;
        Assert.areEqual(expected, actual);
    }
}