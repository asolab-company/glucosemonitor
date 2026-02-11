import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Image("app_ic_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                Spacer()
                Text("Loading...")
                    .font(.callout)
                    .foregroundColor(Color(hex: "171717"))
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}

