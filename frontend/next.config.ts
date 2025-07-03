import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true, // Important for S3
  images: {
    unoptimized: true // Disable Image Optimization API
  }
  /* config options here */
};

export default nextConfig;
