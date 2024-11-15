import SwiftUI

struct InstructionView: View {
    @Binding var showInstruction: Bool
    @Environment(\.colorScheme) var colorScheme
    @Binding var expression: String
    @Binding var postfixElements: [String]
    var isInfix: Bool

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

                        Text(" - 函数：\\sin_{真数}、\\cos_{真数}、\\tan_{真数}、\\log_{底数}_{真数}")

                        Text("中缀表达式输入示例：")
                            .font(.headline)
                            .padding(.top)
                        Text(" - 3 + \\sin_{2}")
                        Text(" - \\log_{2}_{8}")
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
