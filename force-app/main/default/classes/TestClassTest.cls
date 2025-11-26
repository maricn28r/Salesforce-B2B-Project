@isTest
private class TestClassTest {

    @isTest
    static void myUnitTest() {
        Integer expected = 1;
        Integer actual = 3;
        Integer ntr = 333;
        Assert.areEqual(expected, actual);
    }
}