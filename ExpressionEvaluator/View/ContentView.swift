import SwiftUI

struct ContentView: View {
    @State private var expression: String = ""
    @State private var postfixElements: [String] = []
    @State private var convertedExpression: String = ""
    @State private var systemPrompt: String = ""
    @State private var calculationResult: String = ""
    @State private var isEditing: Bool = false
    @State private var isInfix: Bool = true
    @ObservedObject private var evaluator = ExpressionEvaluator()
    @State private var showInstruction: Bool = false
    @Environment(\.colorScheme) var colorScheme
    @State private var showANSBox: Bool = false
    @State private var ansDisplayValue: String = ""
    @State private var isResultHighlighted: Bool = false

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                if isInfix {
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
                                        .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                                        .frame(height: 50)

                                    TextField("", text: $postfixElements[index])
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .frame(minWidth: 40, maxWidth: 100)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
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

                            Button(action: {
                                removePostfixElement()
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.title)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
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
                                    removePostfixElement()
                                    return nil
                                }
                            }
                            return event
                        }
                    }
                }

                HStack(spacing: 20) {
                    Toggle(isOn: $isInfix) {
                        Text(isInfix ? "中缀表达式" : "后缀表达式")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.7))
                    )

                    Button(action: {
                        convertExpression()
                    }) {
                        Text("转换")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CustomButtonStyle())
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)

                    Button(action: {
                        clearAll()
                    }) {
                        Text("清除")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CustomButtonStyle())
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
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
                        if isInfix {
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
                            }
                        } else {
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
                InstructionView(showInstruction: $showInstruction, expression: $expression, postfixElements: $postfixElements, isInfix: $isInfix)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: isInfix)
    }

    func convertExpression() {
        evaluator.conversionSteps.removeAll()
        evaluator.evaluationSteps.removeAll()
        calculationResult = ""
        systemPrompt = ""
        convertedExpression = ""
        isResultHighlighted = false

        do {
            if isInfix {
                let (converted, result) = try evaluator.evaluateExpression(expression, isInfix: true)
                systemPrompt = "输入的是中缀表达式"
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
            } else {
                let (converted, result) = try evaluator.evaluateExpression("", isInfix: false, postfixTokens: postfixElements)
                systemPrompt = "输入的是后缀表达式"
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
        calculationResult = ""
        ansDisplayValue = ""
        isResultHighlighted = false

        withAnimation {
            showANSBox = false
        }
    }

    func addPostfixElement() {
        postfixElements.append("")
    }

    func removePostfixElement() {
        if !postfixElements.isEmpty {
            postfixElements.removeLast()
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
        if isInfix {
            expression += "\\ANS"
        } else {
            postfixElements.append("\\ANS")
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(colorScheme == .dark ? Color.black.opacity(configuration.isPressed ? 0.2 : 0.3) : Color.white.opacity(configuration.isPressed ? 0.6 : 0.7))
            )
            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}


#Preview {
    ContentView()
}
