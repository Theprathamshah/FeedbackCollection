import express from 'express';
import prisma from '@/lib/db';


const router = express.Router();

// Create feedback
router.post('/', async (req, res): Promise<void> => {

  try {
    const { title, body, score } = req.body;
    console.log('Creating feedback with title:', title);
    if (!title || !body) {
      res.status(400).json({ error: 'title and body required' });
      return;
    }

    const data: any = { title, body };
    if (typeof score === 'number') {
      data.score = score;
    }

    const fb = await prisma?.feedback.create({
      data,
    });
    console.log('result from post api is', fb)
    res.status(201).json(fb);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Get all feedback
router.get('/', async (_req, res) => {

  try {
    if (!prisma) {
      console.log('Database not initialized')
      res.status(500).json({ error: 'Database not initialized' });
      return;
    }
    const all = await prisma?.feedback.findMany({ orderBy: { createdAt: 'desc' } });
    console.log("All feedbacks:", all);
    res.json(all);
  } catch {
    res.status(500).json({ error: 'Server error' });
  }
});

// Get single feedback
router.get('/:id', async (req, res): Promise<void> => {
  try {
    const fb = await prisma?.feedback.findUnique({ where: { id: parseInt(req.params.id) } });
    if (!fb) {
      res.status(404).json({ error: 'Not found' });
      return;
    }
    res.json(fb);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Update feedback
router.patch('/:id', async (req, res) => {
  try {
    const { title, body } = req.body;
    const fb = await prisma?.feedback.update({
      where: { id: parseInt(req.params.id) },
      data: { title, body },
    });
    res.json(fb);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

// Delete feedback
router.delete('/:id', async (req, res) => {
  try {
    await prisma?.feedback.delete({ where: { id: parseInt(req.params.id) } });
    res.status(204).send();
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

// Upvote
router.post('/:id/upvote', async (req, res) => {
  try {
    const fb = await prisma?.feedback.update({
      where: { id: parseInt(req.params.id) },
      data: { score: { increment: 1 } },
    });
    res.json(fb);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

// Downvote
router.post('/:id/downvote', async (req, res) => {
  try {
    const fb = await prisma?.feedback.update({
      where: { id: parseInt(req.params.id) },
      data: { score: { decrement: 1 } },
    });
    res.json(fb);
  } catch {
    res.status(404).json({ error: 'Not found' });
  }
});

export const FeedbackRouter = router;
