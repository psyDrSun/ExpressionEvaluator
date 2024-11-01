import SwiftUI

struct InstructionView: View {
    @Binding var showInstruction: Bool
    @Environment(\.colorScheme) var colorScheme
    @Binding var expression: String
    @Binding var postfixElements: [String]
    @Binding var isInfix: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("说明书")
                    .font(.largeTitle)
                    .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("支持的功能：")
                            .font(.headline)
                            .onTapGesture {
                                if expression.isEmpty && postfixElements.isEmpty {
                                    generateRandomExpression()
                                }
                            }

                        Text(" - 函数：\\sin_真数、\\cos_真数、\\tan_真数、\\log_底数_真数")

                        Text("中缀表达式输入示例：")
                            .font(.headline)
                            .padding(.top)
                        Text(" - 3 + \\sin_2")
                        Text(" - \\log_2_8")
                        Text(" - (\\pi * 2)")
                        Text(" - 4 + 3!")
                        Text(" - \\ANS * 2")

                        Text("后缀表达式输入示例：")
                            .font(.headline)
                            .padding(.top)
                        HStack(spacing: 5) {
                            examplePostfixElement("3")
                            examplePostfixElement("4")
                            examplePostfixElement("+")
                            examplePostfixElement("5")
                            examplePostfixElement("*")
                        }

                        Text("注意：")
                            .font(.headline)
                            .padding(.top)
                        Text(" - 请使用 LaTeX 格式输入函数和常数")
                        Text(" - \\ANS 表示上一次计算结果")
                        Text(" - 在后缀表达式输入时，按住 ⌥Option + a 可添加元素，按住 ⌥Option + s 可删除元素")
                    }
                    .padding()
                    .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                }

                Button(action: {
                    showInstruction = false
                }) {
                    Text("关闭")
                        .font(.headline)
                }
                .buttonStyle(CustomButtonStyle())
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
            )
            .padding(40)
        }
    }

    func examplePostfixElement(_ text: String) -> some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.7))
                .frame(height: 30)

            Text(text)
                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                .padding(.horizontal, 5)
        }
    }

    func generateRandomExpression() {
        let functions = ["\\sin", "\\cos", "\\tan", "\\log"]
        let numbers = ["2", "3", "4", "5", "6", "7", "\\pi", "\\e"]
        let operators = ["+", "-", "*", "/"]
        let randomFunction = functions.randomElement()!
        let randomNumber1 = numbers.randomElement()!
        let randomNumber2 = numbers.randomElement()!
        let randomOperator = operators.randomElement()!
        _ = ["(", randomNumber1, randomOperator, "\(randomFunction)_\(randomNumber2)", ")"]
        if isInfix {
            if randomFunction == "\\log" {
                expression = "(\(randomNumber1)\(randomOperator)\(randomFunction)_\(randomNumber2)_\(numbers.randomElement()!))"
            } else {
                expression = "(\(randomNumber1)\(randomOperator)\(randomFunction)_\(randomNumber2))"
            }
        } else {
            if randomFunction == "\\log" {
                postfixElements = [randomNumber1, "\(randomFunction)_\(randomNumber2)_\(numbers.randomElement()!)", randomOperator]
            } else {
                postfixElements = [randomNumber1, "\(randomFunction)_\(randomNumber2)", randomOperator]
            }
        }
    }
}
