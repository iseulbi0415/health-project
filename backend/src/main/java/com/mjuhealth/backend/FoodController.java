package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/foods")
@CrossOrigin(origins = "*")
public class FoodController {

    @Autowired
    private FoodRepository foodRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Food createFood(@RequestBody Food food) {
        return foodRepository.save(food);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Food> getAllFoods() {
        return foodRepository.findAll();
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Food updateFood(@PathVariable Long id, @RequestBody Food food) {
        food.setId(id);
        return foodRepository.save(food);
    }

    @DeleteMapping("/{id}")
    public void deleteFood(@PathVariable Long id) {
        foodRepository.deleteById(id);
    }
}


