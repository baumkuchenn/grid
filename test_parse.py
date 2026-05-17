import re

with open("lib/src/features/workspace/pages/workspace_page.dart") as f:
    text = f.read()

stack = []
for i, char in enumerate(text):
    if char in "({[":
        stack.append((char, i))
    elif char in ")}]":
        if not stack:
            print(f"Error: unexpected {char} at index {i}")
            break
        top, index = stack.pop()
        if (top == '(' and char != ')') or (top == '{' and char != '}') or (top == '[' and char != ']'):
            print(f"Mismatch at index {i}: expected matching for {top} at {index}, but got {char}")
            
            # Print line and column
            line = text[:i].count('\n') + 1
            col = i - text.rfind('\n', 0, i)
            print(f"Line {line}, Column {col}")
            break

if stack:
    print("Unclosed braces:")
    for char, i in stack[-5:]:
        line = text[:i].count('\n') + 1
        col = i - text.rfind('\n', 0, i)
        print(f"  {char} at Line {line}, Column {col}")
else:
    print("All balanced!")

