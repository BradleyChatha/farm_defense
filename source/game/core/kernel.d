module game.core.kernel;

import game.core, game.common;

private:

// START variables.
Service[ServiceType.max + 1] g_services;

public:

enum ServiceType
{
    // Update order depends on order within this enum.
    ERROR,
    debugUI
}

// START data types.
abstract class Service : IMessageHandler
{
    private bool _isPaused;
    private bool _hasStarted;

    final void start()
    {
        assert(!this._hasStarted, "This service cannot be started twice. This indicates a bug.");
        this._hasStarted = true;
        this.onStart();
    }

    final void stop()
    {
        assert(this._hasStarted, "This service cannot be stopped twice. This indicates a bug.");
        this._hasStarted = false;
        this.onStop();
    }

    final void pause()
    {
        this._isPaused = true;
        this.onPause();
    }

    final void resume()
    {
        this._isPaused = false;
        this.onResume();
    }

    @property
    final bool isPaused()
    {
        return this._isPaused;
    }
    
    // Override these as needed.
    protected
    {
        void onStart(){}
        void onStop(){}
        void onPause(){}
        void onResume(){}
        void onFrame(){}
    }
}

// START functions
void servicesRegister(ServiceType type, Service service)
{
    assert(service !is null, "Cannot register a null service.");

    g_services[type] = service;
}

void servicesStart(ServiceType type)
{
    g_services[type].start();
    messageBusSubscribe(g_services[type]);
}

void servicesStop(ServiceType type)
{
    g_services[type].stop();
    messageBusUnsubscribe(g_services[type]);
}

void servicesPause(ServiceType type)
{
    g_services[type].pause();
}

void serviceResume(ServiceType type)
{
    g_services[type].resume();
}

package void servicesOnFrame()
{
    foreach(service; g_services)
    {
        if(service !is null && !service.isPaused)
            service.onFrame();
    }
}