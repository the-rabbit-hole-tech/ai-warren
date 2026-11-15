from __PYPKG__ import hello


def test_hello() -> None:
    assert hello("world") == "Hello, world!"
