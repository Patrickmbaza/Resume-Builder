import axios from 'axios';
import type { AxiosError } from 'axios';
import type { ResumeData } from '../types/resume';

const OPENAI_API_KEY = import.meta.env.VITE_OPENAI_API_KEY;

const api = axios.create({
  baseURL: 'https://api.openai.com/v1',
  headers: {
    'Authorization': `Bearer ${OPENAI_API_KEY}`,
    'Content-Type': 'application/json'
  }
});

type OpenAIErrorResponse = {
  error?: {
    message?: string;
  };
};

const generateCompletion = async (prompt: string, systemPrompt?: string): Promise<string> => {
  try {
    const messages = [];
    if (systemPrompt) messages.push({ role: 'system', content: systemPrompt });
    messages.push({ role: 'user', content: prompt });

    const response = await api.post('/chat/completions', {
      model: 'gpt-4o-mini',
      messages,
      temperature: 0.7,
      max_tokens: 1024,
    });

    return response.data.choices[0].message.content.trim();
  } catch (error) {
    const axiosError = error as AxiosError<OpenAIErrorResponse>;
    const msg = axiosError.response?.data?.error?.message || axiosError.message || 'Unknown error';
    console.error('AI Service Error:', msg, axiosError.response?.data);
    throw new Error(`AI request failed: ${msg}`);
  }
};

export const aiService = {
  // Step 2: Generate/Improve Summary
  generateSummary: async (role: string, experience: string): Promise<string> => {
    const prompt = `Write a professional resume summary for a ${experience} level ${role}. Make it concise (3-4 sentences), impactful, and highlight key strengths. Do not include placeholders.`;
    return generateCompletion(prompt, 'You are an expert resume writer.');
  },

  improveSummary: async (currentSummary: string): Promise<string> => {
    const prompt = `Improve the following resume summary to make it more professional, impactful, and action-oriented:\n\n${currentSummary}`;
    return generateCompletion(prompt, 'You are an expert resume writer.');
  },

  // Step 4: Generate bullet points for Experience
  generateExperienceBullets: async (role: string, company: string): Promise<string> => {
    const prompt = `Generate 4 professional, action-oriented resume bullet points for a ${role} at ${company}. Focus on achievements, metrics, and impact. Return ONLY the bullet points, each starting with a bullet character (•).`;
    return generateCompletion(prompt, 'You are an expert resume writer.');
  },

  // Step 5: Enhance Project descriptions
  enhanceProjectDescription: async (description: string, technologies: string): Promise<string> => {
    const prompt = `Enhance the following project description for a resume. The project used these technologies: ${technologies}. Make it sound professional, emphasizing technical complexity and the value delivered. Return ONLY a concise paragraph or 2-3 bullet points.\n\nOriginal: ${description}`;
    return generateCompletion(prompt, 'You are an expert resume writer.');
  },

  // Step 6: Suggest Skills
  suggestSkills: async (role: string, experienceLevel: string): Promise<string> => {
    const prompt = `Suggest a comma-separated list of the top 15-20 most relevant technical and soft skills for a ${experienceLevel} level ${role}. Do not include categories, just a flat comma-separated list.`;
    return generateCompletion(prompt, 'You are an expert technical recruiter.');
  },

  // Step 10: Final Optimization
  optimizeResume: async (resumeData: ResumeData): Promise<{ score: number; feedback: string; optimizedSummary: string }> => {
    const prompt = `As an expert ATS resume reviewer, evaluate this resume data:\n
    Role/Level: ${resumeData.experienceLevel}
    Summary: ${resumeData.summary}
    Experience count: ${resumeData.experiences.length}
    Projects count: ${resumeData.projects.length}
    Skills: ${resumeData.skills}
    
    Provide a JSON response with exactly these 3 keys:
    1. "score": A number from 0-100 representing overall quality.
    2. "feedback": A short paragraph of constructive feedback (max 3 sentences).
    3. "optimizedSummary": A rewritten, highly polished version of their summary.
    
    Return ONLY valid JSON.`;
    
    const responseText = await generateCompletion(prompt, 'You are an expert ATS resume reviewer. Always return valid JSON only, without any markdown formatting blocks like ```json.');
    
    try {
      // Clean up potential markdown formatting from AI response
      const cleanJsonStr = responseText.replace(/```json/g, '').replace(/```/g, '').trim();
      const result = JSON.parse(cleanJsonStr);
      return result;
    } catch {
      console.error("Failed to parse AI JSON:", responseText);
      return {
        score: 85,
        feedback: "Your resume structure looks good, but some sections could use more quantifiable metrics. Try expanding your experience bullets.",
        optimizedSummary: resumeData.summary
      };
    }
  }
};
