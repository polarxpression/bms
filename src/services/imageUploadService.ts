export const imageUploadService = {
  uploadImage: async (file: File, apiKey: string): Promise<string | null> => {
    if (!apiKey) return null;

    const formData = new FormData();
    formData.append("image", file);
    formData.append("key", apiKey);

    try {
      const response = await fetch("https://api.imgbb.com/1/upload", {
        method: "POST",
        body: formData,
      });

      if (response.ok) {
        const json = await response.json();
        if (json.success) {
          return json.data.url;
        }
      }
      return null;
    } catch (err) {
      console.error("ImgBB Upload Error:", err);
      return null;
    }
  },
};
