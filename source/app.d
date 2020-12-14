module app;

version(Engine_Library){}
else
{
    import engine.init;

    int main(string[] args)
    {
        init_00_init_globals();
        init_03_load_config();
        return 0;
    }
}