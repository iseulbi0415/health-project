package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/foods")
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
}
