import SwiftUI

struct AdminPanelView: View {
    @ObservedObject var engine: GameEngine
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("本机调试"), footer: Text("管理员效果仅在当前对局生效，不会上传或永久保存。")) {
                    Toggle("启用管理员模式", isOn: Binding(
                        get: { engine.state.debug.isAdminMode },
                        set: engine.setAdminMode
                    ))
                }

                if engine.state.debug.isAdminMode {
                    Section(header: Text("资源与防御")) {
                        Toggle("无限金币", isOn: Binding(
                            get: { engine.state.debug.infiniteCoins },
                            set: engine.setInfiniteCoins
                        ))
                        Toggle("房门无敌", isOn: Binding(
                            get: { engine.state.debug.invincibleDoor },
                            set: engine.setInvincibleDoor
                        ))
                        Button("增加 1000 金币", action: engine.addDebugCoins)
                            .disabled(engine.state.phase != .playing)
                        Button("清除本波怪物", action: engine.defeatCurrentWave)
                            .disabled(engine.state.phase != .playing || engine.remainingEnemies == 0)
                            .foregroundColor(.red)
                    }

                    Section(header: Text("游戏速度")) {
                        Picker("倍速", selection: Binding(
                            get: { Int(engine.state.debug.speedMultiplier) },
                            set: { engine.setSpeed(Double($0)) }
                        )) {
                            Text("1x").tag(1)
                            Text("2x").tag(2)
                            Text("4x").tag(4)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Section {
                        Button("重开本局") {
                            engine.restart()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
            .navigationBarTitle("管理员模式", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
