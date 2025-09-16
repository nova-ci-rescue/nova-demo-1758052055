from calculator import add, multiply, power

def test_add():
    assert add(2, 3) == 5

def test_multiply():
    assert multiply(3, 4) == 12

def test_power():
    assert power(2, 3) == 8
