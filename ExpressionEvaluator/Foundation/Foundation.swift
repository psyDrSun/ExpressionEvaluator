import Foundation

enum EvaluationMode {
    case infixToPostfix
    case postfixEvaluation
    case infixEvaluation
}

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
    @Published var humanReadableSteps: [HumanReadableStep] = []

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

    func evaluateExpression(_ expression: String, mode: EvaluationMode, postfixTokens: [String] = []) throws -> (String, String) {
        conversionSteps = []
        evaluationSteps = []
        humanReadableSteps = []

        var tokens: [String] = []

        switch mode {
        case .infixToPostfix:
            tokens = try tokenize(expression)
            let postfix = try infixToPostfix(tokens)
            let postfixExpression = postfix.joined(separator: " ")
            let result = try evaluatePostfix(postfix)
            return (postfixExpression, String(result))
        case .postfixEvaluation:
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
        case .infixEvaluation:
            let result = try evaluateInfix(expression)
            return ("", String(result))
        }
    }

    func tokenize(_ expression: String) throws -> [String] {
        var tokens: [String] = []
        var index = expression.startIndex
        var lastToken: String? = nil

        while index < expression.endIndex {
            let char = expression[index]
            
            // Replace full-width parentheses with standard ones
            let currentChar = char == "（" ? "(" : char == "）" ? ")" : char

            if currentChar.isWhitespace {
                index = expression.index(after: index)
                continue
            } else if currentChar.isNumber || currentChar == "." {
                var number = ""
                while index < expression.endIndex, expression[index].isNumber || expression[index] == "." {
                    number.append(expression[index])
                    index = expression.index(after: index)
                }
                tokens.append(number)
                lastToken = number
            } else if currentChar == "-" {
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
            } else if currentChar == "\\" {
                // Start reading a function
                var function = "\\"
                index = expression.index(after: index)
                while index < expression.endIndex, expression[index].isLetter {
                    function.append(expression[index])
                    index = expression.index(after: index)
                }
                if function == "\\e" || function == "\\pi" || function == "\\ANS" {
                    tokens.append(function)
                    lastToken = function
                } else if ["\\sin", "\\cos", "\\tan", "\\log"].contains(function) {
                    if index < expression.endIndex, expression[index] == "_" {
                        index = expression.index(after: index)
                        var args: [String] = []
                        while true {
                            var arg = ""
                            var parenthesisCount = 0
                            while index < expression.endIndex {
                                let c = expression[index]
                                if c == "(" {
                                    parenthesisCount += 1
                                } else if c == ")" {
                                    parenthesisCount -= 1
                                }
                                if parenthesisCount < 0 {
                                    throw ExpressionError.invalidExpression("Mismatched parentheses")
                                }
                                if c == "_" && parenthesisCount == 0 {
                                    break
                                }
                                arg.append(c)
                                index = expression.index(after: index)
                                if parenthesisCount == 0 && (index == expression.endIndex || "+-*/^()!".contains(expression[index])) {
                                    break
                                }
                            }
                            args.append(arg)
                            if index < expression.endIndex, expression[index] == "_" {
                                index = expression.index(after: index)
                            } else {
                                break
                            }
                        }
                        tokens.append(function + "_" + args.joined(separator: "_"))
                        lastToken = tokens.last
                    } else {
                        throw ExpressionError.invalidExpression("Expected '_' after function name")
                    }
                } else {
                    throw ExpressionError.invalidExpression("Unknown function \(function)")
                }
            } else if "+-*/^()!".contains(currentChar) {
                tokens.append(String(currentChar))
                lastToken = String(currentChar)
                index = expression.index(after: index)
            } else {
                throw ExpressionError.invalidExpression("Unknown character: \(char)")
            }
        }
        tokens.append("#")
        return tokens
    }

    func infixToPostfix(_ tokens: [String]) throws -> [String] {
        outputQueue = []
        operatorStack = []
        operatorStack.append("#")
        var stepCount = 0
        var remainingTokens = tokens

        while !remainingTokens.isEmpty {
            let token = remainingTokens.removeFirst()
            let currentInput = remainingTokens.joined(separator: " ")
            stepCount += 1

            if Double(token) != nil || token == "\\ANS" || constants.keys.contains(token) || isFunctionValue(token) {
                outputQueue.append(token)
            } else if token == "(" {
                operatorStack.append(token)
            } else if token == ")" {
                while let op = operatorStack.last, op != "(", op != "#" {
                    outputQueue.append(operatorStack.removeLast())
                }
                if operatorStack.last == "(" {
                    operatorStack.removeLast()
                } else {
                    throw ExpressionError.invalidExpression("Mismatched parentheses")
                }
            } else if operators.keys.contains(token) {
                let tokenPrecedence = operators[token]!.precedence
                let tokenAssociativity = operators[token]!.associativity

                while let op = operatorStack.last, operators.keys.contains(op), op != "#", op != "(" {
                    let opPrecedence = operators[op]!.precedence
                    if (tokenAssociativity == "Left" && tokenPrecedence <= opPrecedence) ||
                        (tokenAssociativity == "Right" && tokenPrecedence < opPrecedence) {
                        outputQueue.append(operatorStack.removeLast())
                    } else {
                        break
                    }
                }
                operatorStack.append(token)
            } else if token == "#" {
                while let op = operatorStack.last, op != "#" {
                    outputQueue.append(operatorStack.removeLast())
                }
                if operatorStack.last == "#" {
                    operatorStack.removeLast()
                }
                break
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

    func evaluateInfix(_ expression: String) throws -> Double {
        let tokens = try tokenize(expression)
        var tokensCopy = tokens
        tokensCopy.removeLast()
        let result = try computeInfix(tokensCopy)
        return result
    }

    func computeInfix(_ tokens: [String]) throws -> Double {
        let tokens = tokens
        var index = 0
        func parseExpression() throws -> Double {
            var results = [try parseTerm()]
            while index < tokens.count, tokens[index] == "+" || tokens[index] == "-" {
                let op = tokens[index]
                index += 1
                let term = try parseTerm()
                let stepDesc = "\(results.last!) \(op) \(term)"
                let res = op == "+" ? results.last! + term : results.last! - term
                results.append(res)
                humanReadableSteps.append(HumanReadableStep(step: humanReadableSteps.count + 1, operation: stepDesc, result: "\(res)"))
            }
            return results.last!
        }

        func parseTerm() throws -> Double {
            var results = [try parseFactor()]
            while index < tokens.count, tokens[index] == "*" || tokens[index] == "/" {
                let op = tokens[index]
                index += 1
                let factor = try parseFactor()
                let stepDesc = "\(results.last!) \(op) \(factor)"
                let res = op == "*" ? results.last! * factor : results.last! / factor
                results.append(res)
                humanReadableSteps.append(HumanReadableStep(step: humanReadableSteps.count + 1, operation: stepDesc, result: "\(res)"))
            }
            return results.last!
        }

        func parseFactor() throws -> Double {
            if index < tokens.count, tokens[index] == "(" {
                index += 1
                let expr = try parseExpression()
                if index < tokens.count, tokens[index] == ")" {
                    index += 1
                    return expr
                } else {
                    throw ExpressionError.invalidExpression("Mismatched parentheses")
                }
            } else {
                return try parseValue()
            }
        }

        func parseValue() throws -> Double {
            let token = tokens[index]
            index += 1
            if let value = Double(token) {
                return value
            } else if token == "\\ANS" {
                if let previousResult = previousResult {
                    return previousResult
                } else {
                    throw ExpressionError.invalidExpression("No previous result")
                }
            } else if constants.keys.contains(token) {
                return constants[token]!
            } else if isFunctionValue(token) {
                return try evaluateFunctionValue(token)
            } else {
                throw ExpressionError.invalidExpression("Invalid value: \(token)")
            }
        }

        return try parseExpression()
    }

    func factorial(_ n: Int) -> Double {
        if n == 0 || n == 1 {
            return 1.0
        } else {
            return Double(n) * factorial(n - 1)
        }
    }

    func isFunctionValue(_ token: String) -> Bool {
        return token.starts(with: "\\log_") || token.starts(with: "\\sin_") || token.starts(with: "\\cos_") || token.starts(with: "\\tan_")
    }

    func evaluateFunctionValue(_ token: String) throws -> Double {
        if token.starts(with: "\\log_") {
            let components = token.dropFirst(5).split(separator: "_", maxSplits: 1)
            if components.count == 2 {
                let baseExpr = String(components[0])
                let argExpr = String(components[1])
                let baseValue = try evaluateInfix(baseExpr)
                let argValue = try evaluateInfix(argExpr)
                if baseValue <= 0 || baseValue == 1 || argValue <= 0 {
                    throw ExpressionError.invalidExpression("Invalid log parameters")
                }
                return log(argValue) / log(baseValue)
            } else {
                throw ExpressionError.invalidExpression("Invalid log format")
            }
        } else if token.starts(with: "\\sin_") || token.starts(with: "\\cos_") || token.starts(with: "\\tan_") {
            let functionName = String(token.prefix(4))
            let argExpr = String(token.dropFirst(5))
            let argValue = try evaluateInfix(argExpr)
            switch functionName {
            case "\\sin":
                return sin(argValue)
            case "\\cos":
                return cos(argValue)
            case "\\tan":
                return tan(argValue)
            default:
                throw ExpressionError.invalidExpression("Unknown function \(functionName)")
            }
        } else {
            throw ExpressionError.invalidExpression("Unknown function \(token)")
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

struct HumanReadableStep: Identifiable {
    let id = UUID()
    let step: Int
    let operation: String
    let result: String
}
