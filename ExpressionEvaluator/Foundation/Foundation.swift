import Foundation

enum ExpressionError: Error, LocalizedError {
    case invalidExpression(String)

    var errorDescription: String? {
        switch self {
        case .invalidExpression(let message):
            return message
        }
    }
}

class ExpressionEvaluator: ObservableObject {
    @Published var conversionSteps: [OperationStep] = []
    @Published var evaluationSteps: [OperationStep] = []

    var operatorStack: [String] = []
    var outputQueue: [String] = []

    var previousResult: Double? = nil

    let operators: [String: (precedence: Int, associativity: String)] = [
        "+": (precedence: 2, associativity: "Left"),
        "-": (precedence: 2, associativity: "Left"),
        "*": (precedence: 3, associativity: "Left"),
        "/": (precedence: 3, associativity: "Left"),
        "^": (precedence: 4, associativity: "Right"),
        "!": (precedence: 5, associativity: "Right")
    ]

    let constants: [String: Double] = [
        "\\pi": Double.pi,
        "\\e": M_E
    ]

    func evaluateExpression(_ expression: String, isInfix: Bool, postfixTokens: [String] = []) throws -> (String, String) {
        conversionSteps = []
        evaluationSteps = []

        var tokens: [String] = []

        if isInfix {
            tokens = try tokenize(expression)

            let postfix = try infixToPostfix(tokens)
            let postfixExpression = postfix.joined(separator: " ")

            let result = try evaluatePostfix(postfix)

            return (postfixExpression, String(result))
        } else {
            tokens = postfixTokens

            let initialStep = OperationStep(
                step: 0,
                input: tokens.joined(separator: " "),
                operatorStack: "",
                operandStack: "",
                postfix: ""
            )
            evaluationSteps.append(initialStep)

            let result = try evaluatePostfix(tokens)

            return (tokens.joined(separator: " "), String(result))
        }
    }

    func tokenize(_ expression: String) throws -> [String] {
        var tokens: [String] = []
        var index = expression.startIndex
        var lastToken: String? = nil

        while index < expression.endIndex {
            let char = expression[index]

            if char.isWhitespace {
                index = expression.index(after: index)
                continue
            } else if char.isNumber || char == "." {
                var number = ""
                while index < expression.endIndex, expression[index].isNumber || expression[index] == "." {
                    number.append(expression[index])
                    index = expression.index(after: index)
                }
                tokens.append(number)
                lastToken = number
            } else if char == "-" {
                if let last = lastToken, last == ")" || Double(last) != nil || constants.keys.contains(last) || last == "\\ANS" {
                    tokens.append("-")
                    lastToken = "-"
                    index = expression.index(after: index)
                } else {
                    var number = "-"
                    index = expression.index(after: index)
                    if index < expression.endIndex, expression[index].isNumber || expression[index] == "." {
                        while index < expression.endIndex, expression[index].isNumber || expression[index] == "." {
                            number.append(expression[index])
                            index = expression.index(after: index)
                        }
                        tokens.append(number)
                        lastToken = number
                    } else {
                        throw ExpressionError.invalidExpression("Invalid negative number")
                    }
                }
            } else if char == "\\" {
                var command = "\\"
                index = expression.index(after: index)
                while index < expression.endIndex, expression[index].isLetter {
                    command.append(expression[index])
                    index = expression.index(after: index)
                }

                if command == "\\pi" || command == "\\e" || command == "\\ANS" {
                    tokens.append(command)
                    lastToken = command
                } else if command == "\\log" || command == "\\sin" || command == "\\cos" || command == "\\tan" {
                    if index < expression.endIndex, expression[index] == "_" {
                        index = expression.index(after: index)
                        var arg1 = ""
                        while index < expression.endIndex, expression[index] != "_" && expression[index] != "+" && expression[index] != "-" && expression[index] != "*" && expression[index] != "/" && expression[index] != "^" && expression[index] != "!" && expression[index] != "(" && expression[index] != ")" {
                            arg1.append(expression[index])
                            index = expression.index(after: index)
                        }
                        if command == "\\log" {
                            if index < expression.endIndex, expression[index] == "_" {
                                index = expression.index(after: index)
                                var arg2 = ""
                                while index < expression.endIndex, expression[index] != "+" && expression[index] != "-" && expression[index] != "*" && expression[index] != "/" && expression[index] != "^" && expression[index] != "!" && expression[index] != "(" && expression[index] != ")" {
                                    arg2.append(expression[index])
                                    index = expression.index(after: index)
                                }
                                tokens.append("\\log{\(arg1)}{\(arg2)}")
                                lastToken = tokens.last
                            } else {
                                throw ExpressionError.invalidExpression("Invalid log format")
                            }
                        } else {
                            tokens.append("\(command){\(arg1)}")
                            lastToken = tokens.last
                        }
                    } else {
                        throw ExpressionError.invalidExpression("Expected _ after function name")
                    }
                } else {
                    throw ExpressionError.invalidExpression("Unknown function \(command)")
                }
            } else if "+*/^()!".contains(char) {
                tokens.append(String(char))
                lastToken = String(char)
                index = expression.index(after: index)
            } else {
                throw ExpressionError.invalidExpression("Unknown character: \(char)")
            }
        }

        return tokens
    }

    func infixToPostfix(_ tokens: [String]) throws -> [String] {
        outputQueue = []
        operatorStack = []
        var stepCount = 0
        let remainingTokens = tokens + ["#"]
        var index = 0

        while index < remainingTokens.count {
            let token = remainingTokens[index]
            let currentInput = remainingTokens[index...].joined()
            stepCount += 1

            if Double(token) != nil || token == "\\ANS" || constants.keys.contains(token) || isFunctionValue(token) {
                outputQueue.append(token)
                index += 1
            } else if token == "(" {
                operatorStack.append(token)
                index += 1
            } else if token == ")" {
                while let op = operatorStack.last, op != "(" {
                    outputQueue.append(operatorStack.removeLast())
                }
                if operatorStack.last == "(" {
                    operatorStack.removeLast()
                } else {
                    throw ExpressionError.invalidExpression("Mismatched parentheses")
                }
                index += 1
            } else if operators.keys.contains(token) {
                let tokenPrecedence = operators[token]!.precedence
                let tokenAssociativity = operators[token]!.associativity

                while let op = operatorStack.last, operators.keys.contains(op) {
                    let opPrecedence = operators[op]!.precedence
                    if (tokenAssociativity == "Left" && tokenPrecedence <= opPrecedence) ||
                        (tokenAssociativity == "Right" && tokenPrecedence < opPrecedence) {
                        outputQueue.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                operatorStack.append(token)
                index += 1
            } else if token == "#" {
                while operatorStack.last != nil {
                    outputQueue.append(operatorStack.removeLast())
                }
                index += 1
            } else {
                throw ExpressionError.invalidExpression("Unknown symbol: \(token)")
            }

            let step = OperationStep(
                step: stepCount,
                input: currentInput,
                operatorStack: operatorStack.joined(separator: " "),
                operandStack: "",
                postfix: outputQueue.joined(separator: " ")
            )
            conversionSteps.append(step)
        }
        return outputQueue
    }

    func evaluatePostfix(_ tokens: [String]) throws -> Double {
        var stack: [Double] = []
        var stepCount = 0
        var remainingTokens = tokens

        while !remainingTokens.isEmpty {
            let token = remainingTokens.removeFirst()
            let currentInput = remainingTokens.joined(separator: " ")
            stepCount += 1
            if let value = Double(token) {
                stack.append(value)
            } else if token == "\\ANS" {
                if let previousResult = previousResult {
                    stack.append(previousResult)
                } else {
                    throw ExpressionError.invalidExpression("No previous result")
                }
            } else if constants.keys.contains(token) {
                stack.append(constants[token]!)
            } else if let negValue = Double(token), token.first == "-" {
                stack.append(negValue)
            } else if isFunctionValue(token) {
                let value = try evaluateFunctionValue(token)
                stack.append(value)
            } else if operators.keys.contains(token) {
                if token == "!" {
                    guard let a = stack.popLast() else {
                        throw ExpressionError.invalidExpression("Operator \(token) lacks operand")
                    }
                    let result = factorial(Int(a))
                    stack.append(result)
                } else {
                    guard stack.count >= 2 else {
                        throw ExpressionError.invalidExpression("Operator \(token) lacks operands")
                    }
                    let b = stack.removeLast()
                    let a = stack.removeLast()
                    let result: Double
                    switch token {
                    case "+":
                        result = a + b
                    case "-":
                        result = a - b
                    case "*":
                        result = a * b
                    case "/":
                        if b == 0 {
                            throw ExpressionError.invalidExpression("Division by zero")
                        }
                        result = a / b
                    case "^":
                        result = pow(a, b)
                    default:
                        throw ExpressionError.invalidExpression("Unknown operator \(token)")
                    }
                    stack.append(result)
                }
            } else {
                throw ExpressionError.invalidExpression("Unknown symbol \(token)")
            }

            let step = OperationStep(
                step: stepCount,
                input: currentInput,
                operatorStack: "",
                operandStack: stack.map { "\($0)" }.joined(separator: " "),
                postfix: ""
            )
            evaluationSteps.append(step)
        }

        guard stack.count == 1 else {
            throw ExpressionError.invalidExpression("Invalid postfix expression")
        }

        previousResult = stack[0]

        return stack[0]
    }

    func factorial(_ n: Int) -> Double {
        if n == 0 || n == 1 {
            return 1.0
        } else {
            return Double(n) * factorial(n - 1)
        }
    }

    func isFunctionValue(_ token: String) -> Bool {
        return token.starts(with: "\\log{") || token.starts(with: "\\sin{") || token.starts(with: "\\cos{") || token.starts(with: "\\tan{") || token.starts(with: "\\log{")
    }

    func evaluateFunctionValue(_ token: String) throws -> Double {
        if token.starts(with: "\\log{") {
            let baseAndArg = token.dropFirst(5).dropLast()
            let components = baseAndArg.components(separatedBy: "}{")
            if components.count == 2, let base = Double(components[0]), let arg = Double(components[1]) {
                if base <= 0 || base == 1 || arg <= 0 {
                    throw ExpressionError.invalidExpression("Invalid log parameters")
                }
                return log(arg) / log(base)
            } else {
                throw ExpressionError.invalidExpression("Invalid log format")
            }
        } else if token.starts(with: "\\sin{") {
            let argStr = token.dropFirst(5).dropLast()
            if let arg = Double(argStr) {
                return sin(arg)
            } else {
                throw ExpressionError.invalidExpression("Invalid sin argument")
            }
        } else if token.starts(with: "\\cos{") {
            let argStr = token.dropFirst(5).dropLast()
            if let arg = Double(argStr) {
                return cos(arg)
            } else {
                throw ExpressionError.invalidExpression("Invalid cos argument")
            }
        } else if token.starts(with: "\\tan{") {
            let argStr = token.dropFirst(5).dropLast()
            if let arg = Double(argStr) {
                return tan(arg)
            } else {
                throw ExpressionError.invalidExpression("Invalid tan argument")
            }
        } else {
            throw ExpressionError.invalidExpression("Unknown function value \(token)")
        }
    }
}

struct OperationStep: Identifiable {
    let id = UUID()
    let step: Int
    let input: String
    let operatorStack: String
    let operandStack: String
    let postfix: String
}
