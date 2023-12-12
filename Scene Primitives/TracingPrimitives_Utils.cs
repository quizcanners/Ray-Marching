namespace QuizCanners.RayTracing
{
    public static partial class TracingPrimitives
    {
        public enum Shape { Cube, Sphere, AmbientLightSource, SubtractiveCube, Capsule }
        public enum PrimitiveMaterialType { lambertian = 0, metallic = 1, dialectric = 2, glass = 3, emissive = 4, Subtractive = 5 }
    }
}