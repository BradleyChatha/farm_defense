module game.core.scene;

import game.core, game.common, game.graphics;

struct SetSceneInstance
{
    Scene instance;
    ServiceType type;
}

alias SetSceneInstanceMessage = MessageWithData!(MessageType.setSceneInstance, SetSceneInstance);
alias SetActiveSceneMessage   = MessageWithData!(MessageType.setActiveScene, ServiceType);

package final class SceneService : Service
{
    mixin IMessageHandlerBoilerplate;

    private
    {
        ServiceType _activeScene;
    }

    @Subscribe
    void onSetSceneInstance(SetSceneInstanceMessage message)
    {
        assert(message.data.instance !is null);
        servicesRegister(message.data.type, message.data.instance);
    }

    @Subscribe
    void onSetActiveScene(SetActiveSceneMessage message)
    {
        if(this._activeScene == message.data
        || message.data == ServiceType.ERROR)
            return;

        if(this._activeScene != ServiceType.ERROR)
            servicesStop(message.data);

        this._activeScene = message.data;
        servicesStart(message.data);
    }
}

public:

abstract class Scene : Service
{
    protected Camera camera;

    this()
    {
        this.camera = new Camera();
    }

    // Override as needed.
    protected
    {
        void          onUpdate()       { }
        DrawCommand[] drawCommands()   { return null; }
        DrawCommand[] uiDrawCommands() { return null; }
    }

    final override void onFrame()
    {
        this.onUpdate();

        auto commands = this.drawCommands;
        foreach(ref command; commands)
            command.camera = this.camera.view;

        messageBusSubmit!SubmitDrawCommandsMessage(commands);
        messageBusSubmit!SubmitDrawCommandsMessage(this.uiDrawCommands);
    }
}