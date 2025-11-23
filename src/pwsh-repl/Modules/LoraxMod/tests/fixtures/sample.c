#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int multiply(int x, int y) {
    return x * y;
}

int main() {
    int result = add(5, 3);
    printf("Result: %d\n", result);
    return 0;
}
