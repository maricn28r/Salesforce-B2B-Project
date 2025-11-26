@isTest
private class TestClassTest {

    @isTest
    static void myUnitTest() {
        Integer expected = 1;
        Integer actual = 1;
        Assert.areEqual(expected, actual);
    }

    @isTest
    static void myUnitTest2() {
        Integer expected = 3;
        Integer actual = 3;
        Assert.areEqual(expected, actual);
    }

    @isTest
    static void myUnitTest3() {
        Integer expected = 55;
        Integer actual = 55;
        Assert.areEqual(expected, actual);
    }
}