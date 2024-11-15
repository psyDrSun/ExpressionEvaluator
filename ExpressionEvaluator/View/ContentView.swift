import SwiftUI

enum CalculationMode {
    case infixToPostfix
    case postfixEvaluation
    case infixEvaluation
}

enum InputMode {
    case infix
    case postfix
}

struct ContentView: View {
    @State private var expression: String = ""
    @State private var postfixElements: [String] = []
    @State private var convertedExpression: String = ""
    @State private var systemPrompt: String = ""
    @State private var calculationResult: String = ""
    @State private var isEditing: Bool = false
    @State private var inputMode: InputMode = .infix
    @State private var calculationMode: CalculationMode = .infixToPostfix
    @ObservedObject private var evaluator = ExpressionEvaluator()
    @State private var showInstruction: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showANSBox: Bool = false
    @State private var ansDisplayValue: String = ""
    @State private var isResultHighlighted: Bool = false
    @State private var selectedPostfixIndex: Int? = nil

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                if inputMode == .infix {
                    HStack(spacing: 10) {
                        if showANSBox {
                            ZStack(alignment: .center) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                                    .frame(width: 150, height: 50)

                                Text("\\ANS = \(ansDisplayValue)")
                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            }
                            .onTapGesture {
                                addANSToInput()
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        }

                        ZStack(alignment: .center) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                                .frame(height: 50)

                            if expression.isEmpty && !isEditing {
                                Text("输入表达式")
                                    .foregroundColor(.gray)
                                    .transition(.opacity)
                            }

                            TextField("", text: $expression, onEditingChanged: { editing in
                                withAnimation {
                                    isEditing = editing
                                }
                            })
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(height: 50)
                            .multilineTextAlignment(.center)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        }
                        .transition(.move(edge: .trailing))
                    }
                    .padding(.horizontal)
                    .transition(.identity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(postfixElements.indices, id: \.self) { index in
                                ZStack(alignment: .center) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedPostfixIndex == index ? Color.gray.opacity(0.5) : (colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7)))
                                        .frame(height: 50)

                                    TextField("", text: $postfixElements[index], onEditingChanged: { editing in
                                        if editing {
                                            selectedPostfixIndex = index
                                        }
                                    })
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .frame(minWidth: 40, maxWidth: 100)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                    .onTapGesture {
                                        selectedPostfixIndex = index
                                    }
                                }
                            }

                            Button(action: {
                                addPostfixElement()
                            }) {
                                Image(systemName: "plus.circle")
                                    .font(.title)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.1), value: postfixElements)

                            Button(action: {
                                removeSelectedPostfixElement()
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.title)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.1), value: postfixElements)
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 50)
                    .padding(.horizontal)
                    .transition(.identity)
                    .onAppear {
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if event.modifierFlags.contains(.option) {
                                if event.charactersIgnoringModifiers == "a" {
                                    addPostfixElement()
                                    return nil
                                } else if event.charactersIgnoringModifiers == "s" {
                                    removeSelectedPostfixElement()
                                    return nil
                                }
                            }
                            return event
                        }
                    }
                }

                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            inputMode = .infix
                        }
                    }) {
                        Text("中缀输入")
                            .font(.headline)
                            .foregroundColor(inputMode == .infix ? Color.white : (colorScheme == .dark ? Color.white : Color.black))
                    }
                    .buttonStyle(ModeButtonStyle(isSelected: inputMode == .infix))
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: inputMode)

                    Button(action: {
                        withAnimation {
                            inputMode = .postfix
                        }
                    }) {
                        Text("后缀输入")
                            .font(.headline)
                            .foregroundColor(inputMode == .postfix ? Color.white : (colorScheme == .dark ? Color.white : Color.black))
                    }
                    .buttonStyle(ModeButtonStyle(isSelected: inputMode == .postfix))
                    .scaleEffect(1.0)
                    .animation(.easeInOut(duration: 0.1), value: inputMode)
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    if inputMode == .infix {
                        Button(action: {
                            calculationMode = .infixToPostfix
                            performCalculation()
                        }) {
                            Text("中缀转后缀")
                                .font(.headline)
                                .foregroundColor(Color.white)
                        }
                        .buttonStyle(CalculationButtonStyle())

                        Button(action: {
                            calculationMode = .infixEvaluation
                            performCalculation()
                        }) {
                            Text("中缀逻辑求值")
                                .font(.headline)
                                .foregroundColor(Color.white)
                        }
                        .buttonStyle(CalculationButtonStyle())

                        Button(action: {
                            clearAll()
                        }) {
                            Text("清除")
                                .font(.headline)
                                .foregroundColor(Color.red)
                        }
                        .buttonStyle(CalculationButtonStyle())
                    } else {
                        Button(action: {
                            calculationMode = .postfixEvaluation
                            performCalculation()
                        }) {
                            Text("后缀计算")
                                .font(.headline)
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        }
                        .buttonStyle(CalculationButtonStyle())

                        Button(action: {
                            clearAll()
                        }) {
                            Text("清除")
                                .font(.headline)
                                .foregroundColor(Color.red)
                        }
                        .buttonStyle(CalculationButtonStyle())
                    }
                }
                .padding(.horizontal)

                Text("系统提示: \(systemPrompt)")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)

                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                        .frame(height: 50)

                    Text(convertedExpression)
                        .multilineTextAlignment(.center)
                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                }
                .padding(.horizontal)

                Button(action: {
                    isResultHighlighted = true
                    copyResultToClipboard()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isResultHighlighted = false
                        }
                    }
                }) {
                    Text("运算结果: \(calculationResult)")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? Color.yellow : Color.green)
                        .shadow(color: (colorScheme == .dark ? Color.yellow : Color.green).opacity(isResultHighlighted ? 1 : 0), radius: isResultHighlighted ? 10 : 0)
                        .animation(.easeInOut(duration: 2), value: isResultHighlighted)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Text("操作过程:")
                        .font(.headline)

                    ScrollView {
                        if calculationMode == .infixToPostfix {
                            VStack {
                                HStack {
                                    Text("转换步骤").bold().frame(width: 80)
                                    Text("中缀表达式的读入").bold().frame(maxWidth: .infinity, alignment: .leading)
                                    Text("运算符栈").bold().frame(maxWidth: .infinity, alignment: .leading)
                                    Text("后缀表达式").bold().frame(maxWidth: .infinity, alignment: .leading)
                                }
                                ForEach(evaluator.conversionSteps) { item in
                                    HStack {
                                        Text("\(item.step)").frame(width: 80)
                                        Text(item.input).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.operatorStack).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.postfix).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                // Display the result after conversion
                                if !convertedExpression.isEmpty {
                                    HStack {
                                        Spacer().frame(width: 80)
                                        Text("结果:").bold().frame(maxWidth: .infinity, alignment: .leading)
                                        Text(convertedExpression).frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                    }
                                    .padding(.top, 5)
                                }
                            }
                        } else if calculationMode == .postfixEvaluation {
                            VStack {
                                HStack {
                                    Text("计算步骤").bold().frame(width: 80)
                                    Text("后缀表达式的读入").bold().frame(maxWidth: .infinity, alignment: .leading)
                                    Text("操作数和运算结果栈").bold().frame(maxWidth: .infinity, alignment: .leading)
                                }
                                ForEach(evaluator.evaluationSteps) { item in
                                    HStack {
                                        Text("\(item.step)").frame(width: 80)
                                        Text(item.input).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.operandStack).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        } else if calculationMode == .infixEvaluation {
                            VStack {
                                HStack {
                                    Text("计算步骤").bold().frame(width: 80)
                                    Text("操作").bold().frame(maxWidth: .infinity, alignment: .leading)
                                    Text("结果").bold().frame(maxWidth: .infinity, alignment: .leading)
                                }
                                ForEach(evaluator.humanReadableSteps) { item in
                                    HStack {
                                        Text("\(item.step)").frame(width: 80)
                                        Text(item.operation).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(item.result).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                )
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .padding(.horizontal)
                .frame(maxHeight: .infinity)

                Spacer()
            }
            .onAppear {
                NSApp.windows.forEach { window in
                    window.isOpaque = false
                    window.backgroundColor = .clear
                }
            }
            .padding()

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showInstruction = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.title)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    .padding()
                }
            }

            if showInstruction {
                InstructionView(showInstruction: $showInstruction, expression: $expression, postfixElements: $postfixElements, isInfix: inputMode == .infix)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: inputMode)
    }

    func performCalculation() {
        evaluator.conversionSteps.removeAll()
        evaluator.evaluationSteps.removeAll()
        evaluator.humanReadableSteps.removeAll()
        calculationResult = ""
        systemPrompt = ""
        convertedExpression = ""
        isResultHighlighted = false

        // Input validation to prevent crashes on empty input
        if inputMode == .infix && expression.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            systemPrompt = "请输入表达式"
            return
        } else if inputMode == .postfix && postfixElements.isEmpty {
            systemPrompt = "请输入后缀表达式"
            return
        }

        do {
            switch calculationMode {
            case .infixToPostfix:
                let (converted, result) = try evaluator.evaluateExpression(expression, mode: .infixToPostfix)
                systemPrompt = "中缀转后缀并计算完成"
                convertedExpression = converted
                calculationResult = result

                if let value = Double(result) {
                    ansDisplayValue = formatANSValue(value)
                } else {
                    ansDisplayValue = result
                }

                withAnimation {
                    showANSBox = true
                }
            case .postfixEvaluation:
                let (converted, result) = try evaluator.evaluateExpression("", mode: .postfixEvaluation, postfixTokens: postfixElements)
                systemPrompt = "后缀计算完成"
                convertedExpression = converted
                calculationResult = result

                if let value = Double(result) {
                    ansDisplayValue = formatANSValue(value)
                } else {
                    ansDisplayValue = result
                }

                withAnimation {
                    showANSBox = true
                }
            case .infixEvaluation:
                let (converted, result) = try evaluator.evaluateExpression(expression, mode: .infixEvaluation)
                systemPrompt = "中缀逻辑求值完成"
                convertedExpression = converted
                calculationResult = result

                if let value = Double(result) {
                    ansDisplayValue = formatANSValue(value)
                } else {
                    ansDisplayValue = result
                }

                withAnimation {
                    showANSBox = true
                }
            }
        } catch let error as ExpressionError {
            systemPrompt = "输入不合法: \(error.localizedDescription)"
        } catch {
            systemPrompt = "输入不合法"
        }
    }

    func clearAll() {
        expression = ""
        postfixElements.removeAll()
        convertedExpression = ""
        systemPrompt = ""
        evaluator.conversionSteps.removeAll()
        evaluator.evaluationSteps.removeAll()
        evaluator.humanReadableSteps.removeAll()
        calculationResult = ""
        ansDisplayValue = ""
        isResultHighlighted = false
        selectedPostfixIndex = nil

        withAnimation {
            showANSBox = false
        }
    }

    func addPostfixElement() {
        postfixElements.append("")
    }

    func removeSelectedPostfixElement() {
        if let index = selectedPostfixIndex {
            postfixElements.remove(at: index)
            selectedPostfixIndex = nil
        }
    }

    func formatANSValue(_ value: Double) -> String {
        let fullValueString = "\(value)"
        let formattedValue = String(format: "%.6f", value)
        return formattedValue.count < fullValueString.count ? formattedValue : fullValueString
    }

    func copyResultToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(calculationResult, forType: .string)
    }

    func addANSToInput() {
        if inputMode == .infix {
            expression += "\\ANS"
        } else {
            postfixElements.append("\\ANS")
        }
    }
}

struct ModeButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(isSelected ? Color.blue : (colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7)))
            )
            .foregroundColor(isSelected ? Color.white : (colorScheme == .dark ? Color.white : Color.black))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct CalculationButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.7))
            )
            .foregroundColor(.black)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
