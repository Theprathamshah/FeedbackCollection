"use client";
import { useState } from "react";

export default function Home() {
  const [feedback, setFeedback] = useState("");
  const [feedBacks, setFeedBacks] = useState<string[]>([]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (feedback.trim()) {
      setFeedBacks([...feedBacks, feedback.trim()]);
      setFeedback("");
    }
  };

  const handleDelete = (e: React.MouseEvent, idx: number) => {
    e.preventDefault();
    setFeedBacks(feedBacks.filter((_, index) => index !== idx));
  };

  return (
    <div className="flex flex-col items-center min-h-screen px-4 bg-gradient-to-tr from-gray-50 via-white to-gray-100 py-12">
      <header className="text-3xl md:text-4xl font-bold mb-8 text-center text-gray-800">
        Welcome to the Feedback App
      </header>

      <form
        onSubmit={handleSubmit}
        className="w-full max-w-md bg-white p-6 rounded-xl shadow-lg space-y-4 border border-gray-200"
      >
        <input
          type="text"
          value={feedback}
          onChange={(e) => setFeedback(e.target.value)}
          placeholder="Write your feedback..."
          className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
        />

        <button
          type="submit"
          className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 transition-colors font-medium"
        >
          Submit Feedback
        </button>
      </form>

      {feedBacks.length > 0 && (
        <div className="mt-10 w-full max-w-md space-y-4">
          <h2 className="text-xl font-semibold text-gray-700 border-b pb-2">Submitted Feedback</h2>
          <ul className="space-y-2">
            {feedBacks.map((item, idx) => (
              <li
                key={idx}
                className="flex justify-between items-center bg-white border border-gray-200 rounded-lg p-3 shadow-sm hover:shadow-md transition"
              >
                <span className="text-gray-800">{item}</span>
                <button
                  className="text-sm text-red-600 border border-red-500 px-3 py-1 rounded hover:bg-red-100 transition"
                  onClick={(e) => handleDelete(e, idx)}
                >
                  Delete
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      <footer className="mt-16 text-sm text-gray-500">
        &copy; {new Date().getFullYear()} Feedback Collection App
      </footer>
    </div>
  );
}
