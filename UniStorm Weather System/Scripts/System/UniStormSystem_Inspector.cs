using QuizCanners.Inspect;
using QuizCanners.Utils;
using UniStorm.Utility;
using UnityEngine;

namespace UniStorm
{
    public partial class UniStormSystem 
    {
        private readonly pegi.EnterExitContext _context = new();

        public void InspectShort() 
        {
            if (!UniStormInitialized)
                "Not Initialized".PegiLabel().Write_Hint().Nl();
            else
            {

                if ("Skip".PegiLabel().Click())
                    SkipWeatherTransition();

                pegi.Nl();

                int index = 0;

                var rowLimit = pegi.PaintingGameViewUI ? 6 : (int)((Screen.width - 55) / 36f);

                foreach (var w in AllWeatherTypes)
                {
                    if (w)
                    {
                        if (w == CurrentWeatherType)
                            pegi.Draw(w.WeatherIcon, toolTip: w.name);

                        else if (pegi.Click(w.WeatherIcon, toolTip: w.name))
                            ChangeWeather(w);
                    }
                    index++;

                    if (index >= rowLimit)
                    {
                        index = 0;
                        pegi.Nl();
                    }
                }

                pegi.Nl();

            }
        }

        public override void Inspect()
        {
            base.Inspect();

            using (_context.StartContext())
            {
               
                InspectShort();


                "Current Weather Config".PegiLabel().Enter_Inspect(CurrentWeatherType).Nl()
                    .OnChanged(()=> 
                    {
                        SkipWeatherTransition();
                    });
                "General Configuration".PegiLabel().Edit_Enter_Inspect(ref Configuration).Nl();
                "Sounds".PegiLabel().Enter_Inspect(SoundManager).Nl();
                "Particles".PegiLabel().Enter_Inspect(Particles).Nl();
                "Lightning Srikes".PegiLabel().Enter_Inspect(LightingStrikes).Nl();
               
                var cl = Singleton.Get<UniStormClouds>(); 
                "Clouds".PegiLabel().Conditionally_Enter_Inspect(cl, cl).Nl();


            }
        }
        public override string NeedAttention()
        {
            if (!Configuration)
                return "No Configuration Assigned";

            return base.NeedAttention();
        }
    }

    [PEGI_Inspector_Override(typeof(UniStormSystem))] internal class UniStormSystemDrawer : PEGI_Inspector_Override { }
}